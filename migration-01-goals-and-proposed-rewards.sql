-- Kudos — migration 01: goal pinning + kid-proposed rewards
-- Run once in Supabase SQL Editor on an existing project (already on schema.sql).
-- Fresh projects don't need this — schema.sql already includes these columns.

-- Kid-proposed rewards awaiting parent approval (parent sets the real cost).
alter table rewards add column if not exists pending boolean not null default false;
alter table rewards add column if not exists proposed_by uuid references profiles(id);

-- A kid's pinned savings goal (one reward), surfaced on their board.
alter table profiles add column if not exists goal_reward_id uuid references rewards(id) on delete set null;
