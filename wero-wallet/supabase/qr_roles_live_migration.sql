-- La Cantine v8: live role access and secure QR support.
-- Run this once in Supabase SQL Editor after the v7 schema and roles migration.

-- Cashiers/treasurers need names for operations, but not members' email addresses.
create or replace function public.cashier_list_members()
returns table(member_id uuid, display_name text, membership_status public.membership_status, active boolean)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.has_staff_role(array['cashier'::public.app_role, 'treasurer'::public.app_role, 'admin'::public.app_role]) then
    raise exception 'forbidden';
  end if;
  return query
    select p.id, p.display_name, p.membership_status, p.active
      from public.profiles p
     where p.active
     order by p.display_name;
end;
$$;
revoke all on function public.cashier_list_members() from public;
grant execute on function public.cashier_list_members() to authenticated;

-- Private bucket used by recharge receipts.
insert into storage.buckets (id, name, public)
values ('receipts', 'receipts', false)
on conflict (id) do nothing;

drop policy if exists "members upload own receipts" on storage.objects;
create policy "members upload own receipts" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'receipts' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "members and treasurers read receipts" on storage.objects;
create policy "members and treasurers read receipts" on storage.objects
  for select to authenticated
  using (bucket_id = 'receipts' and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or public.current_role() in ('treasurer','admin')
  ));

drop policy if exists "members delete own failed receipt uploads" on storage.objects;
create policy "members delete own failed receipt uploads" on storage.objects
  for delete to authenticated
  using (bucket_id = 'receipts' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- A fresh high-entropy QR token is returned once to its owner; only its SHA-256 hash is stored.
create or replace function public.rotate_my_qr_token()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_token text;
begin
  if v_uid is null or not exists (
    select 1 from public.profiles p where p.id = v_uid and p.active
  ) then
    raise exception 'account inactive';
  end if;
  v_token := encode(extensions.gen_random_bytes(32), 'hex');
  update public.wallets
     set qr_secret_hash = extensions.digest(convert_to(v_token, 'UTF8'), 'sha256'),
         qr_revoked_at = null,
         updated_at = now()
   where member_id = v_uid;
  if not found then raise exception 'wallet missing'; end if;
  insert into public.audit_logs(actor_id, action, subject_id, details)
    values (v_uid, 'qr_rotated', v_uid, jsonb_build_object('owner_id', v_uid));
  return v_token;
end;
$$;

create or replace function public.revoke_my_qr_token()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid := (select auth.uid());
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  update public.wallets
     set qr_secret_hash = null, qr_revoked_at = now(), updated_at = now()
   where member_id = v_uid;
  if not found then raise exception 'wallet missing'; end if;
  insert into public.audit_logs(actor_id, action, subject_id, details)
    values (v_uid, 'qr_revoked', v_uid, jsonb_build_object('owner_id', v_uid));
end;
$$;

create or replace function public.verify_member_qr(p_member_id uuid, p_token text)
returns table(member_id uuid, display_name text, balance_cents bigint)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.has_staff_role(array['cashier'::public.app_role, 'treasurer'::public.app_role, 'admin'::public.app_role]) then
    raise exception 'forbidden';
  end if;
  if p_token is null or length(p_token) < 32 then return; end if;
  return query
    select p.id, p.display_name, w.balance_cents
      from public.profiles p
      join public.wallets w on w.member_id = p.id
     where p.id = p_member_id
       and p.active
       and p.membership_status = 'active'
       and w.qr_revoked_at is null
       and w.qr_secret_hash = extensions.digest(convert_to(p_token, 'UTF8'), 'sha256');
end;
$$;

revoke all on function public.rotate_my_qr_token() from public;
grant execute on function public.rotate_my_qr_token() to authenticated;
revoke all on function public.revoke_my_qr_token() from public;
grant execute on function public.revoke_my_qr_token() to authenticated;
revoke all on function public.verify_member_qr(uuid,text) from public;
grant execute on function public.verify_member_qr(uuid,text) to authenticated;
