-- Kudos — migration 08: parent self-service account deletion (RPC)
-- Run once in Supabase SQL Editor. Lets a signed-in parent erase their own
-- account and ALL associated data in a single call, for privacy/compliance.
--
-- delete_my_account() is a SECURITY DEFINER function that:
--   1. removes the family's proof photos from storage (no FK to cascade), then
--   2. deletes the caller's auth user — which cascades, via
--      families.owner_user_id ... on delete cascade, to families and every
--      family-scoped table (profiles, chores, completions, rewards,
--      redemptions, reward_credits, devices, monthly_summaries).
-- It only ever deletes the CALLER's own account (auth.uid()); a user can never
-- delete anyone else.
--
-- Note: the anonymous `feedback` and `testimonials` tables are not tied to an
-- account (no user id) and are intentionally left untouched.

create or replace function delete_my_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  -- Proof photos live in storage, which has no FK to cascade — remove first.
  delete from storage.objects o
   where o.bucket_id = 'chore-photos'
     and (storage.foldername(o.name))[1] in (
       select f.id::text from families f where f.owner_user_id = uid
     );

  -- Deleting the auth user cascades to families and all family-scoped data.
  delete from auth.users where id = uid;
end;
$$;

revoke all on function delete_my_account() from public, anon;
grant execute on function delete_my_account() to authenticated;
