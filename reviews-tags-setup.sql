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
