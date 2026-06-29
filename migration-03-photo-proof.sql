-- Kudos — migration 03: photo proof for chores
-- Run once in Supabase SQL Editor on an existing project (already on schema.sql).
-- Fresh projects don't need this — schema.sql already includes it.
--
-- Photo proof is opt-in per chore (parents turn it on only where it makes sense —
-- "tidy room", not "brush teeth"). When a flagged chore is completed, the kid
-- attaches a photo; it's stored in a private bucket and shown to the parent in
-- the History view. Path convention: {family_id}/{profile_id}/{timestamp}.{ext}

alter table chores add column if not exists requires_photo boolean not null default false;
alter table completions add column if not exists photo_path text;

-- Private bucket for chore photos.
insert into storage.buckets (id, name, public)
values ('chore-photos', 'chore-photos', false)
on conflict (id) do nothing;

-- Storage RLS: a family can only read/write photos under its own family-id folder.
-- (Uploads happen while authenticated as the family owner — the household account.)
create policy "chore photos read" on storage.objects for select to authenticated
  using (bucket_id='chore-photos' and (storage.foldername(name))[1] in (select id::text from families where owner_user_id=auth.uid()));
create policy "chore photos insert" on storage.objects for insert to authenticated
  with check (bucket_id='chore-photos' and (storage.foldername(name))[1] in (select id::text from families where owner_user_id=auth.uid()));
create policy "chore photos delete" on storage.objects for delete to authenticated
  using (bucket_id='chore-photos' and (storage.foldername(name))[1] in (select id::text from families where owner_user_id=auth.uid()));
