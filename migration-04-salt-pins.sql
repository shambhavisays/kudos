-- Kudos — migration 04: salt PINs
-- Run once in Supabase SQL Editor on an existing project (already on schema.sql).
-- Fresh projects don't need this — schema.sql already includes pin_salt.
--
-- Adds a per-profile random salt for PIN hashing. Existing PINs keep working as
-- legacy unsalted hashes and are transparently upgraded to salted on the next
-- successful entry (handled in the app), so no PIN reset is required.

alter table profiles add column if not exists pin_salt text;
