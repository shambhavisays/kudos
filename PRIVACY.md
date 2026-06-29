# Kudos — Privacy Note

Kudos is a family chore tracker. A parent creates an account and adds their own
children's profiles. This note explains what's stored and how it's protected.
It is written for a small, household-use app — not a legal privacy policy for a
public commercial service.

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
- To delete an entire family and account, the account owner can do so from
  Supabase Auth, or contact the app operator.

## A note for anyone deploying this

If you run Kudos for families beyond your own household, children's data is
regulated (e.g. COPPA in the US, GDPR-K in the EU). You would need verifiable
parental consent, a full privacy policy, and a clear deletion process before
offering it publicly.
