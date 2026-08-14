-- ============================================================================
-- Collection tags: label each collection with a partner + a file type so the
-- Library can filter by them. Run once in Supabase ▸ SQL Editor.
-- Partner values line up with the Partners you keep in the Hub.
-- ============================================================================

alter table public.collections add column if not exists partner   text;
alter table public.collections add column if not exists file_type text;
