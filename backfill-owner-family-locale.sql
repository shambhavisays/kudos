-- Kudos — one-off backfill: set timezone/country on the existing family.
-- Run once in Supabase SQL Editor. NOT a migration — this is data specific to
-- one account, not schema, so it stays out of the numbered migration sequence.
-- Safe to re-run (idempotent update).
--
-- Requires migration-07-schedule-and-family-locale.sql to have run first
-- (adds families.timezone / families.country).

do $$
declare
  target_family_id uuid;
begin
  select f.id into target_family_id
  from families f
  join auth.users u on u.id = f.owner_user_id
  where u.email = 'virajgholap@gmail.com'
  order by f.created_at
  limit 1;

  if target_family_id is null then
    raise exception 'No family found for owner virajgholap@gmail.com — aborting backfill.';
  end if;

  update families
  set timezone = 'America/Chicago',
      country  = 'US'
  where id = target_family_id;

  raise notice 'Backfilled family % with timezone=America/Chicago, country=US', target_family_id;
end $$;
