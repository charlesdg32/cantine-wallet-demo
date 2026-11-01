-- Apply once in SQL Editor to the existing Supabase project before deploying.
-- User-facing roles use these existing database values:
-- member=Adhérent, cashier=Membre actif, treasurer=Trésorier, admin=Administrateur.

-- Preserve members previously marked active in the old status selector.
update public.profiles
set role='cashier'
where role='member' and membership_status='active';

update public.profiles
set membership_status=case when role='member' then 'simple'::public.membership_status else 'active'::public.membership_status end
where membership_status is distinct from
  case when role='member' then 'simple'::public.membership_status else 'active'::public.membership_status end;

-- New public signups are always pending and start with the least-privilege role.
create or replace function public.provision_new_auth_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_name text;
begin
  v_name := coalesce(nullif(trim(new.raw_user_meta_data->>'display_name'), ''), split_part(new.email, '@', 1));
  insert into public.profiles(id, display_name, email, role, membership_status, active)
    values(new.id, v_name, new.email, 'member', 'simple', false);
  insert into public.wallets(member_id) values(new.id);
  return new;
end $$;

-- Admin-only role assignment and approval, with an audit record.
create or replace function public.admin_set_member_access(
  p_member_id uuid,
  p_role public.app_role,
  p_active boolean
)
returns void language plpgsql security definer set search_path = '' as $$
declare v_previous_role public.app_role; v_previous_active boolean;
begin
  if public.current_role() <> 'admin' then raise exception 'forbidden'; end if;
  if p_member_id=(select auth.uid()) and (p_role <> 'admin' or not p_active) then
    raise exception 'cannot remove your own admin access';
  end if;
  select role,active into v_previous_role,v_previous_active from public.profiles where id=p_member_id for update;
  if not found then raise exception 'profile not found'; end if;
  update public.profiles
    set role=p_role,
        membership_status=case when p_role='member' then 'simple'::public.membership_status else 'active'::public.membership_status end,
        active=p_active
    where id=p_member_id;
  insert into public.audit_logs(actor_id,action,subject_id,details)
    values((select auth.uid()),'member_access_changed',p_member_id,
      jsonb_build_object('previous_role',v_previous_role,'new_role',p_role,
        'previous_active',v_previous_active,'new_active',p_active));
end $$;

revoke all on function public.admin_set_member_access(uuid,public.app_role,boolean) from public;
grant execute on function public.admin_set_member_access(uuid,public.app_role,boolean) to authenticated;

-- Give sales access to active members, treasurers and administrators.
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
  if v_role not in ('cashier','treasurer','admin') then raise exception 'forbidden'; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) not between 1 and 30 then raise exception 'invalid cart'; end if;
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

revoke all on function public.cashier_debit(uuid,jsonb) from public;
grant execute on function public.cashier_debit(uuid,jsonb) to authenticated;
