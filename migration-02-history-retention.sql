-- Kudos — migration 02: 13-month history retention + monthly summaries
-- Run once in Supabase SQL Editor on an existing project (already on schema.sql).
-- Fresh projects don't need this — schema.sql already includes it.
--
-- Design: keep ~13 months of raw daily completions (enough for a full
-- Year-in-Review and "vs last year"), and roll older data into tiny per-kid
-- monthly summaries so lifetime stats survive without hoarding kids' daily
-- activity. A monthly pg_cron job rolls up, then trims raw rows past 13 months.
-- Star balances and streaks live on the profile, so trimming never changes them.

-- Per-kid monthly rollup (stars earned, chores done).
create table if not exists monthly_summaries (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  month date not null,                 -- first day of the month
  stars int not null default 0,
  chores int not null default 0,
  unique (profile_id, month)
);
alter table monthly_summaries enable row level security;
create policy "own monthly_summaries" on monthly_summaries
  for all using (family_id in (select owned_family_ids()))
  with check (family_id in (select owned_family_ids()));

-- Rebuild summaries from whatever raw completions still exist. Months already
-- summarized then purged are left untouched (they no longer appear here).
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

-- Trim raw completions on whole-month boundaries past 13 months.
create or replace function kudos_trim_completions()
returns void language sql security definer set search_path = public as $$
  delete from completions
  where completed_on < date_trunc('month', current_date - interval '13 months')::date;
$$;

create or replace function kudos_maintain_history()
returns void language plpgsql security definer set search_path = public as $$
begin
  perform kudos_rollup_summaries();   -- summarize first, so the boundary month is whole
  perform kudos_trim_completions();   -- then drop raw rows older than 13 months
end; $$;

-- Schedule monthly (03:00 on the 1st). pg_cron must be enabled — this enables it.
create extension if not exists pg_cron;
select cron.schedule('kudos-history-maintenance', '0 3 1 * *', 'select kudos_maintain_history();');

-- Backfill summaries once for existing data.
select kudos_rollup_summaries();
