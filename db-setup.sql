-- ####################################################################
-- SOURCE: supabase-setup.sql
-- ####################################################################
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
-- and altered by the tags/versioning sections below, so it MUST exist first.
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


-- ####################################################################
-- SOURCE: storage-setup.sql
-- ####################################################################
-- ============================================================================
-- PDF upload storage: a public bucket for review PDFs uploaded from the Library.
-- Run once in Supabase ▸ SQL Editor. MVP posture: uploads + reads allowed with
-- the anon key, same as the other tables.
-- ============================================================================

-- Public bucket (so the native PDF viewer can read the file by URL).
insert into storage.buckets (id, name, public)
values ('pdf-reviews', 'pdf-reviews', true)
on conflict (id) do update set public = true;

-- Allow uploading into this bucket with the anon key.
drop policy if exists "pdf-reviews insert" on storage.objects;
create policy "pdf-reviews insert" on storage.objects
  for insert to anon, authenticated
  with check (bucket_id = 'pdf-reviews');

-- Allow reading objects in this bucket (public bucket also serves /object/public/…).
drop policy if exists "pdf-reviews read" on storage.objects;
create policy "pdf-reviews read" on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'pdf-reviews');


-- ####################################################################
-- SOURCE: hub-setup.sql
-- ####################################################################
-- ============================================================================
-- Slice 1 — Hub data model: partners, workflows (+ stages), folders.
-- Run once in Supabase ▸ SQL Editor. MVP uses permissive anon policies; these
-- get tightened to real roles once Google SSO is wired (Slice 3).
-- ============================================================================

create table if not exists public.partners (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.workflows (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.workflow_stages (
  id uuid primary key default gen_random_uuid(),
  workflow_id uuid references public.workflows(id) on delete cascade,
  position int not null default 0,
  name text not null,
  assignee_type text not null default 'internal',   -- 'internal' (SSO) | 'external' (link)
  assignees text,                                     -- comma-separated emails
  created_at timestamptz not null default now()
);

create table if not exists public.folders (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  parent_id uuid references public.folders(id) on delete cascade,
  partner_id uuid references public.partners(id) on delete set null,
  workflow_id uuid references public.workflows(id) on delete set null,  -- default workflow inherited by media in this folder
  created_at timestamptz not null default now()
);

-- RLS (MVP: open to the anon key, same as the existing tables; tighten in Slice 3)
do $$
declare t text;
begin
  foreach t in array array['partners','workflows','workflow_stages','folders'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists "%s anon all" on public.%I', t, t);
    execute format('create policy "%s anon all" on public.%I for all using (true) with check (true)', t, t);
  end loop;
end $$;


-- ####################################################################
-- SOURCE: workflow-upgrade.sql
-- ####################################################################
-- ============================================================================
-- Workflow templates upgrade — match the PageProof model:
--   each step has REVIEWERS and/or APPROVERS (by email), and a gate:
--   a step "waits for the approver to approve" when it has approvers,
--   otherwise it "flows through without waiting."
-- Run once in Supabase ▸ SQL Editor (safe to re-run).
-- ============================================================================

alter table public.workflow_stages
  add column if not exists approvers text;                    -- comma-separated approver emails
alter table public.workflow_stages
  add column if not exists waits boolean not null default false; -- step blocks until approved

-- (existing column) assignees  = REVIEWER emails, comma-separated
-- (existing column) assignee_type stays for internal/SSO vs external/link; defaults to external


-- ####################################################################
-- SOURCE: collections-setup.sql
-- ####################################################################
-- ============================================================================
-- Collections: bundle several library reviews into one shareable batch so a
-- reviewer gets a single link. Run once in Supabase ▸ SQL Editor.
-- MVP uses permissive anon policies, matching the existing tables.
-- ============================================================================

create table if not exists public.collections (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_by text,
  created_at timestamptz not null default now()
);

-- Join table: an item (review) can live in multiple collections.
create table if not exists public.collection_items (
  id uuid primary key default gen_random_uuid(),
  collection_id uuid not null references public.collections(id) on delete cascade,
  review_id uuid not null references public.reviews(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (collection_id, review_id)
);

-- RLS (MVP: open to the anon key, same as reviews/review_comments)
do $$
declare t text;
begin
  foreach t in array array['collections','collection_items'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists "%s anon all" on public.%I', t, t);
    execute format('create policy "%s anon all" on public.%I for all using (true) with check (true)', t, t);
  end loop;
end $$;


-- ####################################################################
-- SOURCE: collections-tags-setup.sql
-- ####################################################################
-- ============================================================================
-- Collection tags: label each collection with a partner + a file type so the
-- Library can filter by them. Run once in Supabase ▸ SQL Editor.
-- Partner values line up with the Partners you keep in the Hub.
-- ============================================================================

alter table public.collections add column if not exists partner   text;
alter table public.collections add column if not exists file_type text;


-- ####################################################################
-- SOURCE: reviews-tags-setup.sql
-- ####################################################################
-- ============================================================================
-- Item-level tags. Every review (image, PDF, video link, website) can carry
-- namespaced tags so any item — including a lone video link — is filterable by
-- Team / Partner / Program (plus free-form tags), with or without a collection.
-- Run once in Supabase ▸ SQL Editor.
--
-- Values are stored namespaced, e.g.:
--   team:Creative Services   partner:Salve Regina   program:MSN-FNP   Fall 26
-- (entries without a "ns:" prefix are free tags). This means new tag kinds and
-- values need NO migration — you just type them.
-- ============================================================================

alter table public.reviews add column if not exists tags text[] not null default '{}';
create index if not exists reviews_tags_idx on public.reviews using gin (tags);


-- ####################################################################
-- SOURCE: versioning-setup.sql
-- ####################################################################
-- ============================================================================
-- Version history for UPLOADED reviews (images + PDFs).
-- Run once in Supabase ▸ SQL Editor. MVP posture: full access with the anon
-- key, same as the other review tables.
--
-- Model: a review is ONE library card. Each uploaded version is a row here.
-- v1 is the original. Comments are keyed by each version's file URL (every
-- upload gets a unique URL), so a new version automatically starts a fresh
-- comment thread while older versions keep their own notes for reference.
-- A review with NO rows here is treated as a single version (v1 = reviews.url).
-- ============================================================================

create table if not exists public.review_versions (
  id uuid primary key default gen_random_uuid(),
  review_id uuid not null references public.reviews(id) on delete cascade,
  v int not null,                       -- 1 = original, then 2, 3, …
  url text not null,                    -- public URL of this version's file
  status text not null default 'in_review',
  created_by text,
  created_at timestamptz not null default now(),
  unique (review_id, v)
);

create index if not exists review_versions_review_idx on public.review_versions(review_id);

alter table public.review_versions enable row level security;
drop policy if exists "review_versions all" on public.review_versions;
create policy "review_versions all" on public.review_versions
  for all to anon, authenticated using (true) with check (true);

-- Pointer to the current (latest) version number on the review card.
alter table public.reviews add column if not exists current_v int not null default 1;


