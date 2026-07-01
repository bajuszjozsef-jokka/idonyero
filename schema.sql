-- ============================================================================
-- IDŐNYERŐ – Adatbázis séma (Supabase / PostgreSQL)
-- ============================================================================
-- Futtatás: Supabase projekt SQL Editorában, egyszer, létrehozáskor.
-- A tábla- és mezőnevek megegyeznek a projekt specifikációjával.
-- ============================================================================

create extension if not exists pgcrypto;

-- ----------------------------------------------------------------------------
-- Ügyfelek
-- ----------------------------------------------------------------------------
create table if not exists clients (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  industry text,
  website text,
  target_audience text,
  brand_voice text,
  active_channels text[] default '{}',
  notes text,
  color text,
  status text not null default 'active'
    check (status in ('active', 'paused', 'archived', 'trash')),
  starred boolean not null default false,
  trashed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- Projekt kontextus (AI által feltöltött, projekt indításakor)
-- ----------------------------------------------------------------------------
create table if not exists project_context (
  id uuid primary key default gen_random_uuid(),
  client_id uuid references clients(id) on delete cascade,
  scraped_data jsonb,
  summary text,
  keywords text[] default '{}',
  competitors text[] default '{}',
  strengths text[] default '{}',
  weaknesses text[] default '{}',
  focus_areas text[] default '{}',
  created_at timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- Csapattagok (előkészítés jövőbeli csapatkezeléshez – UI-ban még nincs)
-- ----------------------------------------------------------------------------
create table if not exists team_members (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  email text,
  role text,
  created_at timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- Blokkok
-- ----------------------------------------------------------------------------
create table if not exists blocks (
  id uuid primary key default gen_random_uuid(),
  client_id uuid references clients(id) on delete cascade,
  type text not null check (type in (
    'meta_copy', 'ads_copy', 'campaign_strategy', 'campaign_optimization',
    'landing_page', 'seo_audit', 'blog_post', 'competitor_analysis'
  )),
  title text,
  status text not null default 'draft'
    check (status in ('draft', 'reviewing', 'approved', 'delivered')),
  content jsonb,
  input jsonb,
  export_format text check (export_format in ('docx', 'copy', 'html')),
  standalone boolean not null default false,
  -- Előkészítés: határidő és csapattag hozzárendelés (UI-ban még nem jelenik meg)
  assigned_to uuid references team_members(id),
  due_date timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- Verziókövetés
-- ----------------------------------------------------------------------------
create table if not exists block_versions (
  id uuid primary key default gen_random_uuid(),
  block_id uuid references blocks(id) on delete cascade,
  version_number int not null,
  content jsonb,
  note text,
  saved_at timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- Agent futások
-- ----------------------------------------------------------------------------
create table if not exists agent_outputs (
  id uuid primary key default gen_random_uuid(),
  block_id uuid references blocks(id) on delete cascade,
  agent_type text not null check (agent_type in (
    'meta_copywriter', 'ads_copywriter', 'marketing_strategist', 'data_analyst',
    'seo_specialist', 'web_developer', 'blog_writer', 'competitor_analyst',
    'client_communication',
    'corrector', 'code_reviewer', 'seo_reviewer', 'data_reviewer'
  )),
  input jsonb,
  output text,
  ran_at timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- Indexek
-- ----------------------------------------------------------------------------
create index if not exists idx_blocks_client_id on blocks(client_id);
create index if not exists idx_block_versions_block_id on block_versions(block_id);
create index if not exists idx_agent_outputs_block_id on agent_outputs(block_id);
create index if not exists idx_project_context_client_id on project_context(client_id);
create index if not exists idx_clients_status on clients(status);

-- ----------------------------------------------------------------------------
-- updated_at automatikus frissítése
-- ----------------------------------------------------------------------------
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_clients_updated_at on clients;
create trigger trg_clients_updated_at
  before update on clients
  for each row execute function set_updated_at();

drop trigger if exists trg_blocks_updated_at on blocks;
create trigger trg_blocks_updated_at
  before update on blocks
  for each row execute function set_updated_at();

-- ----------------------------------------------------------------------------
-- Row Level Security
-- ----------------------------------------------------------------------------
-- Megjegyzés: az alkalmazás jelenleg nem tartalmaz felhasználói bejelentkezést
-- (egycsapatos belső eszköz). Az RLS bekapcsolt, de a policy-k jelenleg minden
-- kérést engedélyeznek az anon/authenticated kulcsokkal. Ha később bevezetésre
-- kerül a Supabase Auth, ezeket a policy-kat kell szigorítani
-- (pl. auth.uid() alapján, csapattagsághoz kötve).

alter table clients enable row level security;
alter table project_context enable row level security;
alter table blocks enable row level security;
alter table block_versions enable row level security;
alter table agent_outputs enable row level security;
alter table team_members enable row level security;

drop policy if exists "clients_all" on clients;
create policy "clients_all" on clients for all using (true) with check (true);

drop policy if exists "project_context_all" on project_context;
create policy "project_context_all" on project_context for all using (true) with check (true);

drop policy if exists "blocks_all" on blocks;
create policy "blocks_all" on blocks for all using (true) with check (true);

drop policy if exists "block_versions_all" on block_versions;
create policy "block_versions_all" on block_versions for all using (true) with check (true);

drop policy if exists "agent_outputs_all" on agent_outputs;
create policy "agent_outputs_all" on agent_outputs for all using (true) with check (true);

drop policy if exists "team_members_all" on team_members;
create policy "team_members_all" on team_members for all using (true) with check (true);
