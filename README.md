# Review Suite

A lightweight, self-hosted review-and-comment suite. Upload images, PDFs, or
video links — or point it at any live web page — and collect pinned comments,
replies, and resolve/approve status in one shared library. Runs as static HTML
on GitHub Pages with a Supabase project for storage. No build step, no framework.

Everything you need to point it at your own accounts lives in **one file:
`config.js`**.

---

## What's in here

| File | What it is |
|------|-----------|
| `config.js` | **The only file you edit.** Your Supabase URL + key, proxy URL, overlay URL, and the app name. |
| `library.html` | The home page — the shared library of all reviews, with tags and filters. `index.html` redirects here. |
| `image.html` / `video.html` / `pdf.html` | Dedicated reviewers for an image, a video link, or a PDF. |
| `decision.html` | Video + decision (approve/changes) view. |
| `collection.html` | Bundle several reviews into one shareable link. |
| `hub.html` | Passcode-gated admin hub (partners, workflows, folders). Default passcode `changeme`. |
| `dashboard.html` | Read-only roll-up of all feedback across pages, with CSV export. |
| `generate.html` | Builds a "review any live URL" link that runs through the proxy. |
| `start.html` / `review-launch.html` | Setup + dashboard page that builds the bookmarklet. |
| `install.html` / `bookmarklet.html` | The bookmarklet install pages. |
| `review-overlay.js` | The commenting overlay injected into a live page by the bookmarklet/proxy. |
| `supabase-function-review.ts` | The proxy Edge Function (deploy to Supabase). |
| `db-setup.sql` | All database setup in one file, in the right order. (Individual `*-setup.sql` files are also included.) |
| `_selftest.html` | A local mock page for testing the overlay. Safe to delete. |

---

## Setup (about 15 minutes)

### 1. Create a Supabase project
supabase.com → **New project**. Wait for it to finish provisioning.

### 2. Create the database
Supabase ▸ **SQL Editor** ▸ New query ▸ paste **`db-setup.sql`** ▸ **Run**.
(That's all eight setup scripts in dependency order. It's safe to re-run.)

### 3. Deploy the proxy (for "review any live URL")
Supabase ▸ **Edge Functions** ▸ Deploy a new function ▸ name it exactly **`review`**
▸ paste **`supabase-function-review.ts`** ▸ Deploy. Then:
- In the function's settings, turn **OFF "Verify JWT"** (so reviewers don't need to log in).
- Add a secret **`OVERLAY_URL`** = the public URL of `review-overlay.js` (you'll get this in step 5,
  e.g. `https://YOUR-GH-USER.github.io/YOUR-REPO/review-overlay.js`).
- Optional: add **`ALLOW_HOSTS`** (comma-separated, e.g. `example.com,webflow.io`) to stop the proxy
  being used as an open proxy. Leave unset to allow any site.

`SUPABASE_URL` and `SUPABASE_ANON_KEY` are provided by Supabase automatically.

### 4. Fill in `config.js`
From Supabase ▸ **Project Settings ▸ API**, copy your **Project URL** and **anon/public** key into:
```js
supabaseUrl: 'https://YOUR-PROJECT.supabase.co',
supabaseKey: 'YOUR-SUPABASE-ANON-KEY',
proxyUrl:    'https://YOUR-PROJECT.supabase.co/functions/v1/review',  // if you named the function "review"
overlayUrl:  'https://YOUR-GH-USER.github.io/YOUR-REPO/review-overlay.js',
brand: { name: 'Review Studio' }   // change to whatever you want shown top-left
```

### 5. Put it on GitHub Pages
Create a new **public** GitHub repo, push these files, then in the repo:
**Settings ▸ Pages ▸ Source: Deploy from a branch ▸ `main` / root**.

```bash
cd review-suite
git init && git add . && git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/YOUR-GH-USER/YOUR-REPO.git
git push -u origin main
```

Your site will be at `https://YOUR-GH-USER.github.io/YOUR-REPO/`. That URL + `/review-overlay.js`
is the `overlayUrl` from step 4 and the `OVERLAY_URL` secret from step 3.

### 6. Set the hub passcode
`hub.html` is gated by a passcode. The default is **`changeme`**. To change it, run:
```bash
echo -n 'YOUR-PASSCODE' | shasum -a 256
```
and paste the hex into `PASS_HASH` near the top of `hub.html`'s script. Set `PASS_HASH=''` to remove
the gate entirely.

---

## Using it

- **Review files:** open `library.html`, add an image/PDF/video, share the link. Reviewers click to
  drop pinned comments, reply, and mark items resolved/approved.
- **Review a live web page:** open `generate.html`, paste the page URL, share the generated link — it
  runs through the proxy and loads the comment overlay on top of the real site. (Or install the
  bookmarklet from `install.html` to comment on any page you're already viewing.)
- **See everything:** `dashboard.html` rolls up all feedback with CSV export.

Comments are scoped per page/asset, and pins re-anchor to the element you clicked (they survive
scrolling and reloads).

---

## Notes & customizing

- **The anon key is public by design.** It's embedded in the pages and the bookmarklet. The SQL uses
  permissive policies suited to an internal review tool. If you review anything sensitive, tighten the
  Row Level Security policies in Supabase and consider the `ALLOW_HOSTS` restriction on the proxy.
- **Tag seeds** (teams, sources) are just starter examples — edit `TEAM_SEED` / `SOURCE_SEED` near the
  top of `library.html`'s script, or ignore them and build tags as you go.
- **Colors / theme** live in the `<style>` block of each HTML file (a dark palette). There's no central
  theme file; search-and-replace the hex values if you want a different look. The app **name** is
  central — it's `brand.name` in `config.js`.
- **Hosting the overlay:** GitHub Pages (step 5) is simplest. You can alternatively upload
  `review-overlay.js` to the public `review` Supabase Storage bucket and point `overlayUrl` there.
