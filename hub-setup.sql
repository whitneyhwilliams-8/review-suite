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
