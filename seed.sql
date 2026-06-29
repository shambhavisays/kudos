-- Kudos — OPTIONAL demo data
-- You do NOT need this for normal use: signing up in the app builds a real family
-- for you. This is only for poking around the schema with sample data.
--
-- Because families are owned by a Supabase Auth user, you must first have an auth
-- user to own the demo family. Easiest path:
--   1. Run schema.sql.
--   2. Sign up once in the app (or create a user in Dashboard -> Authentication -> Users).
--   3. Copy that user's UUID and paste it into demo_owner below.
--   4. Run this file in the SQL Editor.
--
-- Starter PINs (change them in-app under Parent settings -> PINs):
--   Riya (kid):  1234        Dad (parent):  333333

do $$
declare
  demo_owner uuid := 'PASTE-YOUR-AUTH-USER-UUID-HERE';
  fam_id uuid;
  kid_id uuid;
  parent_id uuid;
begin
  if demo_owner is null or demo_owner = 'PASTE-YOUR-AUTH-USER-UUID-HERE' then
    raise exception 'Set demo_owner to a real auth.users id first (see comments above).';
  end if;

  insert into families (owner_user_id, name) values (demo_owner, 'Demo Family') returning id into fam_id;

  insert into profiles (family_id, name, emoji, role, age, daily_goal, pin_hash)
    values (fam_id, 'Riya', '🦄', 'kid', 8, 50, encode(digest('1234','sha256'),'hex'))
    returning id into kid_id;

  insert into profiles (family_id, name, emoji, role, daily_goal, pin_hash)
    values (fam_id, 'Dad', '🧑', 'parent', 0, encode(digest('333333','sha256'),'hex'))
    returning id into parent_id;

  insert into chores (family_id, profile_id, emoji, name, points, cadence) values
    (fam_id, kid_id, '🛏️', 'Make bed', 5, 'daily'),
    (fam_id, kid_id, '🪥', 'Brush teeth', 5, 'daily'),
    (fam_id, kid_id, '🧸', 'Put toys away', 5, 'daily'),
    (fam_id, kid_id, '📚', 'Homework', 10, 'daily'),
    (fam_id, kid_id, '📖', 'Read 20 min', 10, 'daily');

  insert into rewards (family_id, owner, emoji, name, cost, tier) values
    (fam_id, 'both', '📺', '30 min screen time', 50, 'instant'),
    (fam_id, 'both', '🌙', 'Stay up 15 min', 60, 'instant'),
    (fam_id, 'both', '🍕', 'Pick dinner menu', 80, 'weekly'),
    (fam_id, 'both', '🎬', 'Movie night', 120, 'weekly'),
    (fam_id, 'both', '🧸', 'Small toy', 200, 'monthly');

  raise notice 'Demo family id: %', fam_id;
end $$;
