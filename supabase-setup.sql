-- ============================================================================
-- Review Suite — Supabase setup
-- Run this ONCE in your Supabase project:  Dashboard ▸ SQL Editor ▸ New query ▸
-- paste ▸ Run.  Creates the comments table, open access policies (internal tool),
-- and a public bucket to host the overlay script.
-- ============================================================================

-- 1) Comments table -----------------------------------------------------------
create table if not exists public.review_comments (
  id         uuid primary key default gen_random_uuid(),
  project    text        not null,
  page       text        not null,
  author     text        not null,
  body       text        not null,
  anchor     jsonb,                       -- where the pin is (element selector + offset)
  parent_id  uuid        references public.review_comments(id) on delete cascade,
  resolved   boolean     not null default false,
  created_at timestamptz not null default now()
);

create index if not exists review_comments_project_idx on public.review_comments (project, page);

-- 2) Access policies ----------------------------------------------------------
-- This is an internal review tool. The anon key is embedded in the bookmarklet,
-- so we allow anon read/write on THIS table only. (No other tables are exposed.)
alter table public.review_comments enable row level security;

drop policy if exists "review anon read"   on public.review_comments;
drop policy if exists "review anon insert" on public.review_comments;
drop policy if exists "review anon update" on public.review_comments;
drop policy if exists "review anon delete" on public.review_comments;

create policy "review anon read"   on public.review_comments for select using (true);
create policy "review anon insert" on public.review_comments for insert with check (true);
create policy "review anon update" on public.review_comments for update using (true) with check (true);
create policy "review anon delete" on public.review_comments for delete using (true);

-- 1b) Reviews table ----------------------------------------------------------
-- Every library card is a "review": an uploaded image/PDF or a pasted
-- video/website link. It is referenced by collection_items and review_versions
-- and altered by the tags/versioning sections, so it MUST exist first.
-- (project = the stable per-item key that comments are scoped to.)
create table if not exists public.reviews (
  id         uuid primary key default gen_random_uuid(),
  project    text        not null,
  name       text,
  url        text,
  status     text        not null default 'in_review',   -- in_review | approved | changes
  archived   boolean     not null default false,
  created_by text,
  created_at timestamptz not null default now()
);
create index if not exists reviews_project_idx on public.reviews (project);

alter table public.reviews enable row level security;
drop policy if exists "reviews anon all" on public.reviews;
create policy "reviews anon all" on public.reviews
  for all to anon, authenticated using (true) with check (true);

-- 3) Public bucket to host the overlay script --------------------------------
-- (Optional but recommended: keeps hosting + storage in one place.)
-- After running this, go to Storage ▸ review ▸ upload  review-overlay.js
insert into storage.buckets (id, name, public)
values ('review', 'review', true)
on conflict (id) do update set public = true;

-- allow public read of files in the 'review' bucket
drop policy if exists "review bucket public read" on storage.objects;
create policy "review bucket public read"
  on storage.objects for select
  using (bucket_id = 'review');

-- Done. Copy your Project URL and anon key from Settings ▸ API into start.html.
