-- Kudos — migration 09: joint rewards (kids pool their stars toward one goal)
-- Run once in Supabase SQL Editor.
--
-- rewards.owner gains a third mode:
--   'both'    — shown to every kid, but each kid spends their OWN stars
--               (unchanged: sharing the definition, not the progress).
--   'profile' — tied to a single kid via owner_profile_id (unchanged).
--   'joint'   — NEW. One shared family goal: every kid's stars count toward it
--               together, and claiming it spends from the pool (the app deducts
--               the cost from each kid in proportion to what they've saved).
--
-- Nothing else changes; existing rewards keep their current owner value.

alter table rewards drop constraint if exists rewards_owner_check;
alter table rewards add constraint rewards_owner_check
  check (owner in ('both','profile','joint'));
