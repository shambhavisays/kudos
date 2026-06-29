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
  cadence text not null default 'daily' check (cadence in ('daily','weekday','weekly','monthly','oneoff')),
  weekdays int[],
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
  owner text not null default 'both' check (owner in ('both','profile')),
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
