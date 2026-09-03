# CLAUDE.md — orientation for a Claude instance working in this folder

This primes you (a future Claude Code / Claude instance) so you can help set up or
extend this project without re-discovering it. Read this first, then `README.md`
for the user-facing setup steps.

## What this is

**Review Suite** — a self-hosted review-and-comment tool. Static HTML pages on
GitHub Pages, backed by a Supabase project for storage. No build step, no
framework, no npm. Users upload images / PDFs / video links (or point it at a
live web page) and collect pinned comments, replies, and resolve/approve status
in one shared library.

It is a de-branded, portable fork of an internal tool ("iDesign Site Review").
All iDesign branding and secrets have been removed. Treat it as a clean template.

## Architecture (read before editing)

- **`config.js` is the single source of config.** It sets `window.APP = {supabaseUrl,
  supabaseKey, proxyUrl, overlayUrl, brand:{name}}`. Every page loads it via
  `<script src="config.js"></script>` **before** its own inline script, then reads
  `window.APP.*`. To point the suite at a new Supabase/GitHub, the user edits ONLY
  this file. Do not re-hardcode URLs/keys into the pages.
- **`review-overlay.js` is the exception** — it gets injected into *other* people's
  pages (via the bookmarklet or the proxy), so it can't load `config.js`. Its
  config arrives at runtime through `window.IDR_CONFIG` (injected by the proxy /
  the bookmarklet builder). Its hardcoded `SUPA_URL`/`SUPA_KEY` are placeholder
  fallbacks only.
- **`supabase-function-review.ts`** is the "review any live URL" proxy. Deploy as a
  Supabase Edge Function named `review`, with Verify JWT OFF. It's env-driven
  (`SUPABASE_URL`, `SUPABASE_ANON_KEY` auto-provided; set `OVERLAY_URL`, optional
  `ALLOW_HOSTS`). It fetches a target URL, strips CSP, injects the overlay.
- **`db-setup.sql`** = all 8 `*-setup.sql` scripts concatenated in dependency order.
  Run it once in the Supabase SQL Editor. The individual files are kept too.
- **Pages:** `library.html` is the home (index.html redirects to it). Reviewers:
  `image/video/pdf/decision/collection.html`. Admin: `hub.html` (passcode-gated),
  `dashboard.html` (feedback roll-up). Bookmarklet/live-URL: `generate.html`,
  `install.html`, `bookmarklet.html`, `start.html` / `review-launch.html` (setup).
- **`_selftest.html`** is a local mock page for testing the overlay. Safe to delete.

## Theme / branding

- **Light, minimal theme** (converted from the original dark forest/mustard look).
  Colors live per-file in each page's `<style>` via a `:root` variable block; there
  is **no** central theme file, but the token values are kept identical across files.
- Tokens: `--bg` page bg **#f5f6f8**, `--surf` cards/header **#ffffff**, `--surf2`
  **#eef1f4**, `--field` **#f7f8fa**, `--line` **#e2e6ea**, `--primary` accent
  **Sage #4f7a61**, `--primary2` light sage **#6a9a80** (hover + links), `--green`
  semantic success **#16a34a**, `--text` **#1f2937**, `--muted` **#6b7280**. Plus
  three helper tokens added during the light conversion: **`--onPrimary`** (#ffffff —
  text/icons that sit ON the accent), **`--heading`** (#0f172a — strong headings),
  **`--stage`** (#e5e7eb — neutral bg behind the white PDF/image pages).
- **To re-tint the accent:** change `--primary` / `--primary2` in every file's
  `:root`. On-accent text uses `--onPrimary`, so it stays readable automatically.
  Semantic status colors (green resolved/approved, amber/red changes/open) are kept.
- `start.html` / `review-launch.html` use a *separate* token set (`--blue` = accent,
  `--ink` / `--navy` = text, `--bg`). Retint those there.
- The brand name shown top-left comes from `config.js` `brand.name` (currently
  **"WW Review"**), rendered into any `.brandmark` element by config.js on load.
- **Tagging is currently disabled in `library.html`** (search `tagging disabled for
  now`): the Filter-by-tag sidebar, the per-item **Tags** button, item tag chips, and
  the collection **Tag items** button are commented out. The tag DB columns and the
  tag-editor modal/JS remain — re-enable by uncommenting those four spots.

## Gotchas

- **Do not blind find-replace hex colors.** `#252425` is used both as a surface
  fill AND as button *text* on mustard; a global swap would turn button text green.
  Change colors via the `:root` tokens, and handle literal exceptions by property
  context (`background:` vs `color:`).
- **`hub.html` passcode:** `PASS_HASH` is the SHA-256 of the passcode; default is
  `changeme`. Change: `echo -n 'NEW' | shasum -a 256`. Set `PASS_HASH=''` to disable
  the gate.
- **Local preview:** it's static files — serve with `python3 -m http.server` from
  this folder (or the app's launch config). With placeholder `config.js`, Supabase
  calls fail gracefully (the UI shows "run the setup SQL") — that's expected until
  real keys are in.
- **The anon key is public by design** and the SQL uses permissive policies (fine
  for internal review). For anything sensitive, tighten Supabase RLS and set
  `ALLOW_HOSTS` on the proxy.

## Setup path (what the user is trying to do)

1. Create a Supabase project. 2. Run `db-setup.sql`. 3. Deploy the edge function
`review` (Verify JWT off; set `OVERLAY_URL`). 4. Fill in `config.js`. 5. Push to a
public GitHub repo and enable Pages. 6. Set the hub passcode. Full detail is in
`README.md`.
