# Kudos — Privacy Note

Kudos is a family chore tracker. A parent creates an account and adds their own
children's profiles. This note is a technical companion to the app's actual
**Terms of Service** and **Privacy Policy** (in-app, linked from the landing
page footer and the signup consent checkbox) — those are the governing
documents; this file just explains what's stored and how it's protected, for
anyone reading the code.

## What we store

- **Parent account:** email address (for login) — handled by Supabase Auth.
- **Profiles:** the names, emoji, and ages you enter for your kids and parents.
- **Activity:** chores, completions, stars, streaks, rewards, redemptions, and
  any notes (e.g. a reading log) you add.
- **Photos:** only when a parent turns on "require a photo" for a specific chore.
  Photos are stored in a private bucket, visible only to your own family.

We do **not** collect location, contacts, payment information, or analytics/
advertising trackers. Kids do not have their own logins or email addresses.

## How it's protected

- Every row is isolated per family by database Row Level Security — one family
  can never read another family's data.
- In-app PINs are salted and hashed; they separate profiles on a shared device.
- Proof photos live in a private store and are shown only via short-lived links.

## Data retention

Detailed daily activity is kept about **13 months**, then reduced to small
monthly summaries — we don't hold on to children's day-to-day activity longer
than needed. Lifetime totals (stars, streaks) are kept on the profile.

## Your choices

- A parent can remove a profile at any time (Parent settings → Family), which
  deletes that person's chores and history.
- A parent can delete their entire account and family at any time from Parent
  settings → Account. This is self-service and immediate: it erases proof
  photos, then the login itself, which cascades to remove every family-scoped
  record (profiles, chores, completions, rewards, credits, devices, summaries).

## A note on the legal pages

The in-app Terms of Service and Privacy Policy (including the parental-consent
checkbox at signup) were self-drafted for a free side project — they have not
been reviewed by an attorney. That's a deliberate choice given the scope: no
ads, no third-party trackers, no data sale, and a working deletion path. Anyone
running this for a larger or monetized audience should get those pages
reviewed by counsel first, particularly for COPPA (US) and GDPR-K (EU)
compliance.
