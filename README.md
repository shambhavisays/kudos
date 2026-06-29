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
3. **Apply migrations.** Run any `migration-*.sql` files (in order) the same way. Fresh projects can skip these — `schema.sql` already includes them — but they're how existing databases pick up later features.
4. **Wire up your project.** In `index.html`, set `SUPABASE_URL` and `SUPABASE_ANON_KEY` (Settings → API, or Settings → Data API for the URL) to your project's values.
5. **(Optional) Email confirmation.** By default Supabase makes new users confirm via an email link. For instant signup during a demo, turn it off: Authentication → Sign In / Providers → User Signups → toggle off "Confirm email." The app handles both modes — with confirmation on, signup shows a "check your email" screen and finishes setup when the user returns and logs in.
6. **Deploy** (see below), open the site, and click **Get started**.

## Features

**Accounts & onboarding**
- Email/password parent accounts via Supabase Auth (one household account per family)
- Value-first onboarding: age-banded starter chores (4–6 / 7–9 / 10–12 / teen), personalize by the child's age, then sign up to save
- Profile management: add/remove kids and parents, set PINs (Parent settings → Family)

**Chores**
- Daily + weekday-scheduled chores, time-of-day grouping (morning / afternoon / evening / anytime)
- Negative-point chores for behavior (whining, tantrums)
- Kid-proposed chores with a parent approval queue
- Habit graduation (chores done 21+ days in a month flagged to "graduate")
- Reading-log / notes, full per-kid history (past year)

**Rewards & motivation**
- Tiered rewards (instant / weekly / monthly), per-kid or shared, chosen from a **tier + owner picker** in the add-reward form; a starter set is seeded for new families
- **Goal pinning** — a kid pins one reward as their savings goal; a "Saving up for X" progress strip surfaces on their board
- **Propose-a-reward** — kids suggest rewards that land in the parent's approval queue (parent sets the cost)
- **Photo proof** — optional per chore (parent ticks "require a photo"); completing a flagged chore attaches a photo to a private Storage bucket, shown to the parent as a thumbnail in History
- Condition-gated rewards + banked credits (perfect-week, "all chores today," etc.) — runtime supports them; create them via SQL for now
- Streaks with one monthly streak-freeze per kid

**Delight & overview**
- Per-kid board accent color, time-of-day greeting, varied praise on completion, dynamic "X chores to go" progress copy
- **Weekly recap** card — stars earned, chores done, best day, and a Mon–Fri sparkline
- **WallBoard** — a read-only "Family board" (opened from the profile picker, no PIN) showing all kids at once for a shared always-on screen; designed to look intentional even at zero progress

## Security model

Row Level Security scopes every row to families owned by the authenticated user (`auth.uid()`). A logged-in parent can only ever read or write their own family's data. The in-app PIN is a convenience separator between profiles on a shared device, not a database boundary — the real boundary is the parent's account; PINs are salted + SHA-256 hashed (per-profile random salt). The WallBoard is exposed without a PIN because it is strictly read-only. See [PRIVACY.md](PRIVACY.md) for what's stored and retained.

This is a **household-account** model (like Netflix/Disney+ profiles), appropriate for a chore tracker with no money or location data. A per-user-account model (Apple Family Sharing / Greenlight style) would be the right upgrade if real allowance money is ever added.

**Dependencies.** The Supabase client library is self-hosted (`lib/supabase.umd.js`, pinned to 2.45.4) and served from our own domain rather than a third-party CDN — no runtime supply-chain dependency. Update it by replacing that one file.

**Data retention.** Raw daily completions are kept ~13 months (enough for a full year + "vs. last year"), then rolled into tiny per-kid monthly summaries and trimmed — data-minimization by design for children's activity. A monthly `pg_cron` job (`kudos_maintain_history`) handles the rollup and trim; star balances and streaks live on the profile, so trimming never changes them. The History view shows daily detail for ~3 months and monthly summaries beyond.

## Roadmap / not built yet

- No per-kid login or "join code" device pairing — every device logs in with the one family account (fine for a household; a v2 would add per-member accounts)
- Photo proof is mandatory-once-flagged but can't be reviewed/approved as a gate (the photo is attached and shown to the parent, not an approval step that withholds points)
- Gated-reward and weekday-only reward rules can't be created from the UI yet (schema + runtime support them; add via SQL)
- No Google login (email/password only for now), no focus-reflection mechanic, no weekly parent-review or year-in-review screen, no Google Calendar integration

## Files

- `index.html` — the entire app
- `lib/supabase.umd.js` — self-hosted Supabase client library (pinned 2.45.4)
- `schema.sql` — full consolidated schema + RLS (run once on a fresh project)
- `migration-01-goals-and-proposed-rewards.sql` — adds goal pinning + proposed-reward columns to an existing project
- `migration-02-history-retention.sql` — adds monthly summaries + the 13-month retention job to an existing project
- `migration-03-photo-proof.sql` — adds photo-proof columns + the private Storage bucket and policies to an existing project
- `migration-04-salt-pins.sql` — adds the per-profile PIN salt column to an existing project
- `PRIVACY.md` — plain-language privacy note (what's stored, retention, deletion)
- `seed.sql` — optional demo data (see below)

## Demo data (optional)

`seed.sql` creates a sample family with a kid and starter chores/rewards so you can poke around without going through signup. It's **optional** and not needed for normal use — onboarding builds a real family for you. To use it, run it after `schema.sql` and read the notes inside (it needs a Supabase Auth user id to own the demo family).

## Deploying

Static site, no build step. Deploy via Vercel or Netlify by connecting this GitHub repo — no build command, publish directory is the repo root.
