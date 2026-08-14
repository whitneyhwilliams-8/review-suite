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
