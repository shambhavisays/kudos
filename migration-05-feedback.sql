-- Migration 05 — anonymous feedback inbox
-- Adds a `feedback` table that anyone (signed in or not) can submit to from the
-- landing page, but that NOBODY can read back through the public anon key. You
-- read submissions in the Supabase dashboard (Table editor → feedback) or via
-- the service_role key. This is the same RLS posture as the rest of the app:
-- the anon key can only do exactly what a policy allows — here, insert and
-- nothing else.
--
-- Safe to run on an existing project. schema.sql already includes this for
-- fresh projects.

create table if not exists feedback (
  id uuid primary key default gen_random_uuid(),
  message text not null check (char_length(message) between 1 and 2000),
  email text check (email is null or char_length(email) <= 254),
  source text,                         -- where it came from, e.g. 'landing'
  created_at timestamptz not null default now()
);

alter table feedback enable row level security;

-- Anyone may submit. There is deliberately NO select/update/delete policy, so
-- the anon (and authenticated) roles can insert but can never read, edit, or
-- delete rows — submissions are write-only from the client's point of view.
drop policy if exists "anyone can submit feedback" on feedback;
create policy "anyone can submit feedback"
  on feedback for insert
  to anon, authenticated
  with check (true);
