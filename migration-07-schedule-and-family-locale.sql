-- Kudos — migration 07: chore scheduling modes + family locale
-- Run once in Supabase SQL Editor on an existing project (already on schema.sql).
-- Fresh projects don't need this — schema.sql already includes these columns.
--
-- Adds:
--   1. chores.schedule_mode — pairs with the existing weekdays int[] column.
--      'include' (default): chore shows only on the listed weekdays (today's
--      behavior, unchanged). 'exclude': chore shows every day EXCEPT the listed
--      weekdays ("every day except weekends" style rules).
--   2. chores.occurs_on — nullable date for one-time (cadence='oneoff') chores.
--      Existing oneoff rows (previously inert in the app) stay hidden until
--      given a date.
--   3. cadence gains a 'holiday' value — chore shows only on US federal
--      holidays (evaluated in the family's timezone). The existing check
--      constraint is dropped and recreated with the wider allow-list.
--   4. families.timezone / families.country — per-family locale, replacing the
--      previously hardcoded America/Chicago + US-only assumptions. New families
--      capture these at signup; the existing family is set via a separate
--      one-off backfill (backfill-owner-family-locale.sql — NOT part of this
--      migration).

alter table chores add column if not exists schedule_mode text not null default 'include'
  check (schedule_mode in ('include','exclude'));

alter table chores add column if not exists occurs_on date;

-- Widen the cadence allow-list to include 'holiday'. The constraint name below
-- is Postgres's default for an inline check (<table>_<column>_check); if your
-- project renamed it, adjust this line (verify with \d chores first).
alter table chores drop constraint if exists chores_cadence_check;
alter table chores add constraint chores_cadence_check
  check (cadence in ('daily','weekday','weekly','monthly','oneoff','holiday'));

alter table families add column if not exists timezone text;
alter table families add column if not exists country text;
