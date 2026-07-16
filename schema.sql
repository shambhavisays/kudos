-- Kudos — Supabase schema (consolidated, multi-tenant + auth)
-- Run this once in Supabase Dashboard -> SQL Editor -> New query -> paste -> Run.
--
-- Multi-tenant model: each family is owned by one Supabase Auth user (the parent
-- who signed up). Row Level Security scopes every row to families owned by the
-- authenticated user (auth.uid()). Inside a family, profiles (kids + parents) are
-- separated by an optional PIN — that's an in-app convenience, not a DB boundary.

create extension if not exists pgcrypto;

-- ── Tables ─────────────────────────────────────────────────────────────────

create table families (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  name text not null default 'My Family',
  -- Per-family locale, captured at signup. timezone is an IANA zone
  -- (e.g. 'America/Chicago'); country is an ISO region code (e.g. 'US').
  -- Holiday-aware scheduling only activates when country = 'US'.
  timezone text,
  country text,
  created_at timestamptz not null default now()
);

create table profiles (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  name text not null,
  emoji text not null default '⭐',
  color text not null default '#378ADD',
  role text not null check (role in ('kid','parent')),
  age int,
  daily_goal int not null default 50,
  -- Nullable: parents always have a PIN, kids may not (optional separator).
  -- A null pin_hash means "no PIN" — tapping the profile goes straight in.
  -- pin_salt is the per-profile random salt hashed with the PIN.
  pin_hash text,
  pin_salt text,
  total_points int not null default 0,
  streak int not null default 0,
  freezes int not null default 1,
  last_active_date date,
  created_at timestamptz not null default now()
);

create table chores (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  profile_id uuid references profiles(id) on delete cascade,
  emoji text not null default '⭐',
  name text not null,
  points int not null,
  cadence text not null default 'daily' check (cadence in ('daily','weekday','weekly','monthly','oneoff','holiday')),
  weekdays int[],
  -- Pairs with weekdays: 'include' shows only on the listed weekdays;
  -- 'exclude' shows every day except them. Ignored unless cadence='weekday'.
  schedule_mode text not null default 'include' check (schedule_mode in ('include','exclude')),
  -- The specific date for a one-time (cadence='oneoff') chore.
  occurs_on date,
  -- Time-of-day grouping on the board (null = "Anytime").
  period text check (period in ('morning','afternoon','evening')),
  -- 'baseline' | 'effortful' | 'stretch'. Stretch tasks are bonus and excluded
  -- from goal / unlock math. Null is treated as a normal (non-stretch) chore.
  category text,
  -- Kid-proposed chores wait for parent approval before going live.
  pending boolean not null default false,
  proposed_by uuid references profiles(id),
  -- When true, completing prompts for a note (e.g. a reading log).
  prompts_note boolean not null default false,
  -- When true, completing requires attaching a photo (parent-set, per chore).
  requires_photo boolean not null default false,
  archived boolean not null default false,
  graduated_at timestamptz,
  created_at timestamptz not null default now()
);

create table completions (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  chore_id uuid not null references chores(id) on delete cascade,
  points int not null,
  note text,
  -- Storage path of the proof photo, when the chore requires_photo.
  photo_path text,
  completed_on date not null default current_date,
  created_at timestamptz not null default now(),
  unique (profile_id, chore_id, completed_on)
);

create table rewards (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  -- 'both'  — shown to every kid, each spends their OWN stars.
  -- 'profile' — tied to one kid via owner_profile_id.
  -- 'joint' — one family goal: every kid's stars count toward it together, and
  --           claiming spends from the pool (deducted proportionally).
  owner text not null default 'both' check (owner in ('both','profile','joint')),
  owner_profile_id uuid references profiles(id) on delete cascade,
  emoji text not null default '🎁',
  name text not null,
  cost int not null,
  tier text not null default 'weekly' check (tier in ('instant','weekly','monthly')),
  -- Optional condition-gating. A reward with any of these set banks a "credit"
  -- each period its conditions are met, instead of being a plain cost-only buy.
  requires_all_today boolean not null default false,
  requires_perfect_week boolean not null default false,
  requires_chore_names text[],
  requires_full_points_excluding text[],
  allowed_weekdays int[],
  -- Kid-proposed rewards wait for parent approval (parent sets the real cost).
  pending boolean not null default false,
  proposed_by uuid references profiles(id),
  archived boolean not null default false,
  created_at timestamptz not null default now()
);

-- A kid can pin one reward as their savings goal; surfaced on their board.
-- Added after rewards exists so the FK resolves; clears if the reward is removed.
alter table profiles add column goal_reward_id uuid references rewards(id) on delete set null;

create table redemptions (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  reward_id uuid not null references rewards(id) on delete cascade,
  cost int not null,
  honored boolean not null default false,
  redeemed_at timestamptz not null default now()
);

-- Banked credits for condition-gated rewards: each met period banks one credit,
-- claimable later. last_period_credited prevents double-crediting the same period.
create table reward_credits (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  reward_id uuid not null references rewards(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  credits int not null default 0,
  last_period_credited text,
  unique (reward_id, profile_id)
);

create table devices (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  label text,
  paired_at timestamptz not null default now()
);

-- Per-kid monthly rollup. Raw completions are kept ~13 months (see retention
-- section below); older activity lives on here as tiny summaries.
create table monthly_summaries (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  month date not null,                 -- first day of the month
  stars int not null default 0,
  chores int not null default 0,
  unique (profile_id, month)
);

-- Anonymous feedback inbox. Not tied to a family — anyone (signed in or not)
-- can submit from the landing page. RLS below allows insert only, so the anon
-- key can never read submissions back; you read them in the dashboard.
create table feedback (
  id uuid primary key default gen_random_uuid(),
  message text not null check (char_length(message) between 1 and 2000),
  email text check (email is null or char_length(email) <= 254),
  source text,
  created_at timestamptz not null default now()
);

-- Opt-in public testimonials. Anyone can submit (from the feedback modal); only
-- rows you approve (approved=true, flipped in the dashboard) are readable through
-- the anon key and shown on the landing page. Unapproved rows stay private.
create table testimonials (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 80),
  role text check (role is null or char_length(role) <= 80),
  quote text not null check (char_length(quote) between 1 and 600),
  approved boolean not null default false,
  created_at timestamptz not null default now()
);

-- ── Row Level Security ───────────────────────────────────────────────────────
-- Every table is scoped to families owned by the authenticated user. A request
-- can only see/modify rows whose family_id belongs to a family it owns; the
-- families table itself is gated on owner_user_id = auth.uid().

alter table families enable row level security;
alter table profiles enable row level security;
alter table chores enable row level security;
alter table completions enable row level security;
alter table rewards enable row level security;
alter table redemptions enable row level security;
alter table reward_credits enable row level security;
alter table devices enable row level security;
alter table monthly_summaries enable row level security;
alter table feedback enable row level security;
alter table testimonials enable row level security;

-- Helper: the set of family ids the current user owns.
create or replace function owned_family_ids()
returns setof uuid
language sql
stable
security definer
set search_path = public
as $$
  select id from families where owner_user_id = auth.uid()
$$;

create policy "own families" on families
  for all using (owner_user_id = auth.uid())
  with check (owner_user_id = auth.uid());

create policy "own profiles" on profiles
  for all using (family_id in (select owned_family_ids()))
  with check (family_id in (select owned_family_ids()));

create policy "own chores" on chores
  for all using (family_id in (select owned_family_ids()))
  with check (family_id in (select owned_family_ids()));

create policy "own completions" on completions
  for all using (family_id in (select owned_family_ids()))
  with check (family_id in (select owned_family_ids()));

create policy "own rewards" on rewards
  for all using (family_id in (select owned_family_ids()))
  with check (family_id in (select owned_family_ids()));

create policy "own redemptions" on redemptions
  for all using (family_id in (select owned_family_ids()))
  with check (family_id in (select owned_family_ids()));

create policy "own reward_credits" on reward_credits
  for all using (family_id in (select owned_family_ids()))
  with check (family_id in (select owned_family_ids()));

create policy "own devices" on devices
  for all using (family_id in (select owned_family_ids()))
  with check (family_id in (select owned_family_ids()));

create policy "own monthly_summaries" on monthly_summaries
  for all using (family_id in (select owned_family_ids()))
  with check (family_id in (select owned_family_ids()));

-- Feedback is write-only from the client: anyone may insert, no one may read
-- back through the API (no select policy). Read submissions in the dashboard.
create policy "anyone can submit feedback" on feedback
  for insert to anon, authenticated
  with check (true);

-- Testimonials: anyone may submit; anyone may read ONLY approved rows. Unapproved
-- submissions are invisible to the anon key until you approve them in the dashboard.
create policy "anyone can submit a testimonial" on testimonials
  for insert to anon, authenticated
  with check (true);
create policy "approved testimonials are public" on testimonials
  for select to anon, authenticated
  using (approved = true);

-- ── History retention (13 months) ───────────────────────────────────────────
-- Keep ~13 months of raw daily completions; roll older activity into
-- monthly_summaries and trim raw rows on whole-month boundaries. A monthly
-- pg_cron job does both. Balances/streaks live on profiles, so trimming raw
-- completions never changes a kid's stars or streak.

create or replace function kudos_rollup_summaries()
returns void language sql security definer set search_path = public as $$
  insert into monthly_summaries (family_id, profile_id, month, stars, chores)
  select family_id, profile_id, date_trunc('month', completed_on)::date,
         sum(points), count(*) filter (where points >= 0)
  from completions
  group by family_id, profile_id, date_trunc('month', completed_on)::date
  on conflict (profile_id, month)
  do update set stars = excluded.stars, chores = excluded.chores;
$$;

create or replace function kudos_trim_completions()
returns void language sql security definer set search_path = public as $$
  delete from completions
  where completed_on < date_trunc('month', current_date - interval '13 months')::date;
$$;

create or replace function kudos_maintain_history()
returns void language plpgsql security definer set search_path = public as $$
begin
  perform kudos_rollup_summaries();
  perform kudos_trim_completions();
end; $$;

create extension if not exists pg_cron;
select cron.schedule('kudos-history-maintenance', '0 3 1 * *', 'select kudos_maintain_history();');

-- ── Photo proof storage ──────────────────────────────────────────────────────
-- Private bucket for chore proof photos. A family can only read/write photos
-- under its own family-id folder. Path: {family_id}/{profile_id}/{timestamp}.{ext}
insert into storage.buckets (id, name, public)
values ('chore-photos', 'chore-photos', false)
on conflict (id) do nothing;

create policy "chore photos read" on storage.objects for select to authenticated
  using (bucket_id='chore-photos' and (storage.foldername(name))[1] in (select id::text from families where owner_user_id=auth.uid()));
create policy "chore photos insert" on storage.objects for insert to authenticated
  with check (bucket_id='chore-photos' and (storage.foldername(name))[1] in (select id::text from families where owner_user_id=auth.uid()));
create policy "chore photos delete" on storage.objects for delete to authenticated
  using (bucket_id='chore-photos' and (storage.foldername(name))[1] in (select id::text from families where owner_user_id=auth.uid()));

-- ── Account self-deletion (privacy/compliance) ───────────────────────────────
-- A signed-in parent can erase their own account and ALL associated data in one
-- call: proof photos, then the auth user (which cascades to families and every
-- family-scoped table). Only ever deletes the caller (auth.uid()).
create or replace function delete_my_account()
returns void language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'Not authenticated'; end if;
  delete from storage.objects o
   where o.bucket_id = 'chore-photos'
     and (storage.foldername(o.name))[1] in (select f.id::text from families f where f.owner_user_id = uid);
  delete from auth.users where id = uid;
end; $$;
revoke all on function delete_my_account() from public, anon;
grant execute on function delete_my_account() to authenticated;
