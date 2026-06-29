# Kudos

Give kids the kudos they deserve — a family chore + rewards tracker. Parents sign up with email, add their kids, and each kid earns ⭐ stars for chores they can spend on rewards.

Built as a single static `index.html` (vanilla JS, no build step) on top of Supabase (Postgres + Auth).

## How it works

- **One household account.** A parent signs up with email + password — that account owns the family. Any device the family uses logs in once with that account.
- **Profiles + PINs.** Inside a family, everyone taps their own profile. Parents always have a 6-digit PIN (it locks Parent settings); kids optionally have a 4-digit PIN (handy for older kids on a shared device).
- **Value-first onboarding.** New parents see starter chores immediately, tune them by their child's age, then create an account to save the board.

## Setup (one-time)

1. **Create a Supabase project** at [supabase.com](https://supabase.com). When prompted, enable the Data API and RLS.
2. **Run the schema.** Dashboard → SQL Editor → New query → paste `schema.sql` → Run. This creates all tables, the auth-scoped Row Level Security policies, and everything the app needs.
3. **Wire up your project.** In `index.html`, set `SUPABASE_URL` and `SUPABASE_ANON_KEY` (Settings → API, or Settings → Data API for the URL) to your project's values.
4. **(Optional) Email confirmation.** By default Supabase makes new users confirm via an email link. For instant signup during a demo, turn it off: Authentication → Sign In / Providers → Email → toggle off "Confirm email." The app handles both modes — with confirmation on, signup shows a "check your email" screen and finishes setup when the user returns and logs in.
5. **Deploy** (see below), open the site, and click **Get started**.

## What's built

- Email/password parent accounts via Supabase Auth (one household account per family)
- Value-first onboarding: age-banded starter chores (4–6 / 7–9 / 10–12 / teen), personalize, then sign up
- Profile management: add/remove kids and parents, set PINs (Parent settings → Family)
- Daily + weekday-scheduled chores, time-of-day grouping (morning/afternoon/evening/anytime)
- Tiered rewards (instant / weekly / monthly), per-kid or shared, with a starter set seeded for new families
- Condition-gated rewards + banked credits (perfect-week, "all chores today," etc.) — machinery is in place; create them in SQL for now
- Streaks with one monthly streak-freeze per kid
- Kid-proposed chores with a parent approval queue
- Habit graduation (chores done 21+ days in a month flagged to "graduate")
- Reading-log / notes, full per-kid history (past year)
- Every completion logged permanently in `completions`

## Security model

Row Level Security scopes every row to families owned by the authenticated user (`auth.uid()`). A logged-in parent can only ever read or write their own family's data. The in-app PIN is a convenience separator between profiles on a shared device, not a database boundary — the real boundary is the parent's account.

This is a **household-account** model (like Netflix/Disney+ profiles), appropriate for a chore tracker with no money or location data. A per-user-account model (Apple Family Sharing / Greenlight style) would be the right upgrade if real allowance money is ever added.

## Known gaps — not built yet

- No per-kid login or "join code" device pairing — every device logs in with the one family account (fine for a household; a v2 would add per-member accounts)
- Gated-reward and weekday-only reward rules can't be created from the UI yet (schema + runtime support them; add via SQL)
- Add-reward form defaults to "weekly / shared" — no tier/owner picker yet
- No Google login (email/password only for now), no focus-reflection mechanic, no weekly parent-review or year-in-review screen, no Google Calendar integration

## Demo data (optional)

`seed.sql` creates a sample family with two kids and starter chores/rewards so you can poke around without going through signup. It's **optional** and not needed for normal use — onboarding builds a real family for you. To use it, run it after `schema.sql` and read the notes inside (it needs a Supabase Auth user id to own the demo family).

## Deploying

Static site, no build step. Deploy via Vercel or Netlify by connecting this GitHub repo — no build command, publish directory is the repo root.
