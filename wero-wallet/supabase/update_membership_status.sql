-- Apply this once in Supabase SQL Editor for an existing project.
-- RLS already limits profile reads; this function lets admins change only
-- membership_status and records the change in the audit log.
create or replace function public.admin_set_membership_status(
  p_member_id uuid,
  p_status public.membership_status
)
returns void language plpgsql security definer set search_path = '' as $$
declare v_previous public.membership_status;
begin
  if public.current_role() <> 'admin' then raise exception 'forbidden'; end if;
  select membership_status into v_previous from public.profiles where id=p_member_id for update;
  if not found then raise exception 'profile not found'; end if;
  update public.profiles set membership_status=p_status where id=p_member_id;
  insert into public.audit_logs(actor_id,action,subject_id,details)
    values((select auth.uid()),'membership_status_changed',p_member_id,
      jsonb_build_object('previous_status',v_previous,'new_status',p_status));
end $$;

revoke all on function public.admin_set_membership_status(uuid,public.membership_status) from public;
grant execute on function public.admin_set_membership_status(uuid,public.membership_status) to authenticated;
