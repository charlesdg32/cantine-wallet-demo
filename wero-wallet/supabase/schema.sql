-- PostgreSQL / Supabase schema for the reviewed production implementation.
-- Run in a fresh Supabase project's SQL editor. Do not expose service_role in a browser.
create extension if not exists pgcrypto;

create type public.app_role as enum ('member','cashier','treasurer','admin');
create type public.topup_status as enum ('pending','approved','rejected');
create type public.transaction_kind as enum ('debit','recharge','refund','adjustment');
create type public.membership_status as enum ('simple','active');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  email text not null,
  role public.app_role not null default 'member',
  -- Membership eligibility is separate from staff permissions (app_role).
  membership_status public.membership_status not null default 'simple',
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create table public.wallets (
  member_id uuid primary key references public.profiles(id),
  balance_cents bigint not null default 0 check (balance_cents >= 0),
  -- Store only a hash of the high-entropy opaque QR secret. Rotate/revoke through RPC.
  qr_secret_hash bytea,
  qr_revoked_at timestamptz,
  updated_at timestamptz not null default now()
);
create table public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  price_cents integer not null check (price_cents > 0),
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create table public.topup_requests (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles(id),
  amount_cents integer not null check (amount_cents between 100 and 50000),
  receipt_path text not null,
  status public.topup_status not null default 'pending',
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id),
  review_note text
);
create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles(id),
  kind public.transaction_kind not null,
  amount_cents bigint not null check (amount_cents > 0),
  label text not null,
  cashier_id uuid references public.profiles(id),
  topup_request_id uuid unique references public.topup_requests(id),
  created_at timestamptz not null default now()
);
create table public.transaction_items (
  transaction_id uuid not null references public.transactions(id),
  product_id uuid not null references public.products(id),
  product_name text not null,
  unit_price_cents integer not null,
  quantity integer not null check (quantity between 1 and 99),
  primary key (transaction_id, product_id)
);
create table public.audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid references public.profiles(id),
  action text not null,
  subject_id uuid,
  details jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create or replace function public.current_role() returns public.app_role
language sql stable security definer set search_path = '' as $$
  select role from public.profiles where id = (select auth.uid()) and active
$$;
create or replace function public.has_staff_role(allowed public.app_role[]) returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce(public.current_role() = any(allowed), false)
$$;

alter table public.profiles enable row level security;
alter table public.wallets enable row level security;
alter table public.products enable row level security;
alter table public.topup_requests enable row level security;
alter table public.transactions enable row level security;
alter table public.transaction_items enable row level security;
alter table public.audit_logs enable row level security;

create policy "profiles self or admin read" on public.profiles for select to authenticated
  using (id = (select auth.uid()) or public.current_role() = 'admin');
create policy "admin manages profiles" on public.profiles for all to authenticated
  using (public.current_role() = 'admin') with check (public.current_role() = 'admin');
create policy "wallet self or staff read" on public.wallets for select to authenticated
  using (member_id = (select auth.uid()) or public.current_role() in ('cashier','treasurer','admin'));
create policy "active catalog read" on public.products for select to authenticated using (active or public.current_role()='admin');
create policy "admin manages catalog" on public.products for all to authenticated
  using (public.current_role()='admin') with check (public.current_role()='admin');
create policy "member or treasurer sees requests" on public.topup_requests for select to authenticated
  using (member_id=(select auth.uid()) or public.current_role() in ('treasurer','admin'));
create policy "member creates own request" on public.topup_requests for insert to authenticated
  with check (member_id=(select auth.uid()) and status='pending');
create policy "own or staff transactions read" on public.transactions for select to authenticated
  using (member_id=(select auth.uid()) or public.current_role() in ('cashier','treasurer','admin'));
create policy "transaction items via transaction" on public.transaction_items for select to authenticated
  using (exists(select 1 from public.transactions t where t.id=transaction_id and
    (t.member_id=(select auth.uid()) or public.current_role() in ('cashier','treasurer','admin'))));
create policy "admin audit read" on public.audit_logs for select to authenticated using (public.current_role()='admin');
-- No client policies permit wallet balance writes, transaction inserts, approvals, or audit edits.

create or replace function public.cashier_debit(p_member_id uuid, p_items jsonb)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_role public.app_role;
  v_balance bigint;
  v_total bigint;
  v_tx uuid := gen_random_uuid();
  v_label text;
begin
  v_role := public.current_role();
  if v_role not in ('cashier','admin') then raise exception 'forbidden'; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) not between 1 and 30 then raise exception 'invalid cart'; end if;
  -- Lock wallet first so simultaneous sales cannot overspend the same balance.
  select w.balance_cents into v_balance from public.wallets w
    join public.profiles p on p.id=w.member_id
    where w.member_id=p_member_id and p.active and p.membership_status='active'
      and w.qr_secret_hash is not null and w.qr_revoked_at is null
    for update of w;
  if not found then raise exception 'inactive wallet'; end if;
  if exists(select 1 from jsonb_array_elements(p_items) i where
      (i->>'product_id') is null or coalesce((i->>'quantity')::integer,0) not between 1 and 99) then raise exception 'invalid cart item'; end if;
  if (select count(*) from jsonb_array_elements(p_items)) <>
     (select count(distinct i->>'product_id') from jsonb_array_elements(p_items) i) then raise exception 'duplicate item'; end if;
  select sum(p.price_cents * (i->>'quantity')::integer) into v_total
    from jsonb_array_elements(p_items) i join public.products p on p.id=(i->>'product_id')::uuid and p.active;
  if v_total is null or (select count(*) from jsonb_array_elements(p_items) i join public.products p on p.id=(i->>'product_id')::uuid and p.active) <> jsonb_array_length(p_items) then raise exception 'unknown product'; end if;
  if v_total > v_balance then raise exception 'insufficient balance'; end if;
  update public.wallets set balance_cents=balance_cents-v_total, updated_at=now() where member_id=p_member_id;
  v_label := (select string_agg(p.name || ' x ' || (i->>'quantity'), ', ')
    from jsonb_array_elements(p_items) i join public.products p on p.id=(i->>'product_id')::uuid);
  insert into public.transactions(id,member_id,kind,amount_cents,label,cashier_id)
    values(v_tx,p_member_id,'debit',v_total,v_label,(select auth.uid()));
  insert into public.transaction_items(transaction_id,product_id,product_name,unit_price_cents,quantity)
    select v_tx,p.id,p.name,p.price_cents,(i->>'quantity')::integer
    from jsonb_array_elements(p_items) i join public.products p on p.id=(i->>'product_id')::uuid;
  insert into public.audit_logs(actor_id,action,subject_id,details)
    values((select auth.uid()),'cashier_debit',p_member_id,jsonb_build_object(
      'transaction_id',v_tx,'member_id',p_member_id,'paid_by_member_id',p_member_id,
      'cashier_id',(select auth.uid()),'amount_cents',v_total,'items',p_items));
  return v_tx;
end $$;

create or replace function public.review_topup(p_request_id uuid, p_approve boolean, p_note text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare v_req public.topup_requests%rowtype;
begin
  if public.current_role() not in ('treasurer','admin') then raise exception 'forbidden'; end if;
  select * into v_req from public.topup_requests where id=p_request_id for update;
  if not found or v_req.status <> 'pending' then raise exception 'request already reviewed'; end if;
  update public.topup_requests set status=case when p_approve then 'approved'::public.topup_status else 'rejected'::public.topup_status end,
    reviewed_at=now(),reviewed_by=(select auth.uid()),review_note=p_note where id=p_request_id;
  if p_approve then
    update public.wallets set balance_cents=balance_cents+v_req.amount_cents,updated_at=now() where member_id=v_req.member_id;
    if not found then raise exception 'wallet missing'; end if;
    insert into public.transactions(member_id,kind,amount_cents,label,topup_request_id)
      values(v_req.member_id,'recharge',v_req.amount_cents,'Recharge approuvée',p_request_id);
  end if;
  insert into public.audit_logs(actor_id,action,subject_id,details)
    values((select auth.uid()),case when p_approve then 'topup_approved' else 'topup_rejected' end,p_request_id,
      jsonb_build_object('member_id',v_req.member_id,'requested_by',v_req.member_id,
        'approved_by',(select auth.uid()),'amount_cents',v_req.amount_cents,'note',p_note));
end $$;

revoke all on function public.cashier_debit(uuid,jsonb) from public;
grant execute on function public.cashier_debit(uuid,jsonb) to authenticated;
revoke all on function public.review_topup(uuid,boolean,text) from public;
grant execute on function public.review_topup(uuid,boolean,text) to authenticated;

-- Provisioning/invitations and QR secret rotation belong in trusted Edge Functions:
-- use Supabase Auth inviteUserByEmail, verify caller role, create profile+wallet,
-- return a one-time random secret (never persist the clear value) and audit the action.
-- Upload receipts to a private Storage bucket; authorize read through a short-lived signed URL.
