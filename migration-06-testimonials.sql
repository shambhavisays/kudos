-- Migration 06 — public testimonials (opt-in, approval-gated)
-- Visitors can submit a testimonial from the feedback modal by ticking the
-- "you can feature this" opt-in. Nothing is shown publicly until you flip
-- approved=true in the Supabase dashboard (Table editor -> testimonials).
--
-- RLS posture: anyone may INSERT (submit); anyone may SELECT only rows where
-- approved=true. So the public anon key can read approved testimonials to show
-- them on the landing page, but can never read unapproved submissions.
--
-- Safe to run on an existing project. schema.sql already includes this for
-- fresh projects.

create table if not exists testimonials (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 80),
  role text check (role is null or char_length(role) <= 80),
  quote text not null check (char_length(quote) between 1 and 600),
  approved boolean not null default false,
  created_at timestamptz not null default now()
);

alter table testimonials enable row level security;

-- Anyone may submit a testimonial.
drop policy if exists "anyone can submit a testimonial" on testimonials;
create policy "anyone can submit a testimonial"
  on testimonials for insert
  to anon, authenticated
  with check (true);

-- Anyone may read ONLY approved testimonials; unapproved rows stay private
-- (readable in the dashboard / via the service_role key).
drop policy if exists "approved testimonials are public" on testimonials;
create policy "approved testimonials are public"
  on testimonials for select
  to anon, authenticated
  using (approved = true);
