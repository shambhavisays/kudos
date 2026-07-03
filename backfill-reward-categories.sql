-- Kudos — one-off: convert the existing family's rewards to the two-category model.
-- Run once in Supabase SQL Editor. Not a migration (account-specific data).
-- Safe to re-run (idempotent).
--
-- Two reward categories in the app:
--   • "Earn by finishing your day" — condition-gated (requires_all_today):
--     banks a credit each day the child finishes ALL their chores. cost = 0.
--   • "Spend your stars" — plain cost, bought with the star balance.
--
-- This script:
--   1) shows the family's current rewards (review before the changes below),
--   2) renames "Stay up 15 min" → a Special-permission reward,
--   3) makes "30 min screen" + that Special-permission reward credit-based,
--   4) de-duplicates rewards that share a name+owner (keeps the oldest),
--   5) shows the result.
--
-- NOTE on the duplicate dinner reward: step 4 only merges rewards with the
-- SAME name. If you have two DIFFERENTLY named dinner rewards (e.g. "Pick
-- dinner menu" AND "Decide Menu"), the step-1 list will show both — archive
-- the unwanted one by hand (see the commented template at the bottom).

-- ── 1. Current rewards (review) ──────────────────────────────────────────────
select r.name, r.emoji, r.cost, r.tier, r.requires_all_today,
       coalesce(p.name,'shared') as owner, r.archived, r.created_at
from rewards r
join families f on f.id = r.family_id
join auth.users u on u.id = f.owner_user_id
left join profiles p on p.id = r.owner_profile_id
where u.email = 'virajgholap@gmail.com'
order by r.archived, owner, r.created_at;

-- ── 2–4. Apply the changes ───────────────────────────────────────────────────
do $$
declare fam_id uuid;
begin
  select f.id into fam_id
  from families f
  join auth.users u on u.id = f.owner_user_id
  where u.email = 'virajgholap@gmail.com'
  order by f.created_at limit 1;
  if fam_id is null then
    raise exception 'No family found for virajgholap@gmail.com';
  end if;

  -- 2. Rename "Stay up 15 min" → Special permission
  update rewards
     set name = 'Special permission (treat, stay up late, pick dinner)'
   where family_id = fam_id and not archived and name = 'Stay up 15 min';

  -- 3. Make the daily-completion rewards credit-based (no star cost)
  update rewards
     set requires_all_today = true, cost = 0, tier = 'instant'
   where family_id = fam_id and not archived
     and name in ('30 min screen',
                  'Special permission (treat, stay up late, pick dinner)');

  -- 4. De-duplicate: archive the newer of any two rewards sharing name + owner
  update rewards r
     set archived = true
   where r.family_id = fam_id and not r.archived
     and exists (
       select 1 from rewards r2
       where r2.family_id = fam_id and not r2.archived
         and lower(r2.name) = lower(r.name)
         and coalesce(r2.owner_profile_id::text,'both') = coalesce(r.owner_profile_id::text,'both')
         and r2.created_at < r.created_at
     );

  raise notice 'Reward categories updated for family %', fam_id;
end $$;

-- ── 5. Result (verify) ───────────────────────────────────────────────────────
select r.name, r.cost, r.requires_all_today,
       case when r.requires_all_today then 'Earn (credit)' else 'Spend stars' end as category,
       coalesce(p.name,'shared') as owner, r.archived
from rewards r
join families f on f.id = r.family_id
join auth.users u on u.id = f.owner_user_id
left join profiles p on p.id = r.owner_profile_id
where u.email = 'virajgholap@gmail.com' and not r.archived
order by r.requires_all_today desc, r.cost, r.name;

-- ── Optional: archive a differently-named duplicate dinner reward by hand.
-- Uncomment and set the exact name to remove (from the step-1 list):
-- update rewards r set archived = true
--   from families f join auth.users u on u.id = f.owner_user_id
--  where r.family_id = f.id and u.email = 'virajgholap@gmail.com'
--    and r.name = 'Decide Menu';   -- ← the duplicate you want to remove
