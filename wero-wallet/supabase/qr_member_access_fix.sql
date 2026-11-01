-- Allow an approved member to use their QR wallet regardless of staff role.
-- cashier/treasurer/admin controls who can scan; profile.active controls approval.
create or replace function public.verify_member_qr(p_member_id uuid, p_token text)
returns table(member_id uuid, display_name text, balance_cents bigint)
language plpgsql security definer set search_path = '' as $$
begin
  if not public.has_staff_role(array['cashier'::public.app_role, 'treasurer'::public.app_role, 'admin'::public.app_role]) then
    raise exception 'forbidden';
  end if;
  if p_token is null or length(p_token) < 32 then return; end if;
  return query
    select p.id, p.display_name, w.balance_cents
      from public.profiles p join public.wallets w on w.member_id = p.id
     where p.id = p_member_id and p.active
       and w.qr_revoked_at is null
       and w.qr_secret_hash = extensions.digest(convert_to(p_token, 'UTF8'), 'sha256');
end;
$$;
revoke all on function public.verify_member_qr(uuid,text) from public;
grant execute on function public.verify_member_qr(uuid,text) to authenticated;
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
    where w.member_id=p_member_id and p.active
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