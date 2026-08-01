-- =============================================================================
-- Research Portfolio — Supabase Postgres schema
--
-- Run this once in the Supabase SQL editor (or via `psql "$DATABASE_URL" -f
-- docs/schema.sql`) against a fresh project to provision every table used by
-- the Flask backend (app/models.py). Column-for-column, this mirrors the
-- SQLAlchemy models exactly, so it is safe to run this first and then point
-- Flask-Migrate at the resulting database as the migration baseline
-- (see docs/DEPLOYMENT.md).
--
-- IMPORTANT — Row Level Security:
-- Supabase automatically exposes every table in the `public` schema through
-- its own PostgREST/GraphQL API using the project's anon/service keys, in
-- ADDITION to whatever the Flask backend does. If RLS is left disabled, an
-- anonymous client that only has your public `anon` key could read or write
-- these tables directly, completely bypassing the Flask API's auth, rate
-- limiting, and validation. This schema enables RLS on every table and
-- deliberately adds NO policies, which makes Supabase's auto-API deny all
-- access by default (both anon and authenticated). All real access must go
-- through the Flask backend using DATABASE_URL, which connects as the
-- Postgres owner role and is not subject to RLS.
-- =============================================================================

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- admins  (single administrator account — no self-registration)
-- ---------------------------------------------------------------------------
create table if not exists admins (
    id                    uuid primary key default gen_random_uuid(),
    email                 varchar(255) not null unique,
    password_hash         varchar(255) not null,
    totp_secret           varchar(64),
    is_2fa_enabled         boolean not null default false,
    last_login_at          timestamptz,
    last_login_ip          varchar(64),
    failed_login_attempts  integer not null default 0,
    locked_until           timestamptz,
    created_at             timestamptz not null default now(),
    updated_at             timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- research_projects
-- ---------------------------------------------------------------------------
create table if not exists research_projects (
    id                     uuid primary key default gen_random_uuid(),
    slug                   varchar(255) not null unique,
    title                  varchar(500) not null,
    category               varchar(120),
    abstract               text,
    research_question      text,
    motivation             text,
    objectives             text,
    methodology            text,
    results                text,
    future_work            text,
    ethics_statement       text,
    "references"           jsonb,
    status                 varchar(20) not null default 'planning'
                            check (status in ('planning','active','completed','published')),
    progress_percentage    integer not null default 0
                            check (progress_percentage between 0 and 100),
    current_phase          varchar(255),
    estimated_completion   date,
    admin_notes            text,
    is_draft               boolean not null default true,
    published_at           timestamptz,
    created_at             timestamptz not null default now(),
    updated_at             timestamptz not null default now()
);
create index if not exists ix_research_projects_slug on research_projects (slug);

create table if not exists milestones (
    id                     uuid primary key default gen_random_uuid(),
    research_project_id    uuid not null references research_projects(id) on delete cascade,
    title                  varchar(500) not null,
    notes                  text,
    milestone_date         date,
    is_complete            boolean not null default false,
    created_at             timestamptz not null default now(),
    updated_at             timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- file_assets  (created before publications/achievements which reference it)
-- ---------------------------------------------------------------------------
create table if not exists file_assets (
    id                     uuid primary key default gen_random_uuid(),
    filename               varchar(500) not null,
    storage_path           varchar(1000) not null,
    description            text,
    version                varchar(50),
    size_bytes             bigint,
    mime_type              varchar(255),
    visibility             varchar(20) not null default 'private'
                            check (visibility in ('public','view_only','private')),
    download_count         integer not null default 0,
    category               varchar(60),
    created_at             timestamptz not null default now(),
    updated_at             timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- publications
-- ---------------------------------------------------------------------------
create table if not exists publications (
    id                     uuid primary key default gen_random_uuid(),
    slug                   varchar(255) not null unique,
    title                  varchar(500) not null,
    publication_type       varchar(30) not null default 'preprint'
                            check (publication_type in
                                ('paper','technical_report','conference','white_paper','preprint')),
    abstract               text,
    citation               text,
    authors                jsonb,
    publication_date       date,
    doi                    varchar(255),
    file_asset_id          uuid references file_assets(id),
    is_draft               boolean not null default true,
    created_at             timestamptz not null default now(),
    updated_at             timestamptz not null default now()
);
create index if not exists ix_publications_slug on publications (slug);

-- ---------------------------------------------------------------------------
-- software_projects
-- ---------------------------------------------------------------------------
create table if not exists software_projects (
    id                     uuid primary key default gen_random_uuid(),
    slug                   varchar(255) not null unique,
    title                  varchar(500) not null,
    description            text,
    features               jsonb,
    architecture           text,
    technologies           jsonb,
    github_url             varchar(500),
    live_demo_url          varchar(500),
    screenshots            jsonb,
    lessons_learned        text,
    future_improvements    text,
    status                 varchar(20) not null default 'active'
                            check (status in ('planning','active','completed','published')),
    progress_percentage    integer not null default 0
                            check (progress_percentage between 0 and 100),
    is_draft               boolean not null default true,
    created_at             timestamptz not null default now(),
    updated_at             timestamptz not null default now()
);
create index if not exists ix_software_projects_slug on software_projects (slug);

-- ---------------------------------------------------------------------------
-- blog_posts
-- ---------------------------------------------------------------------------
create table if not exists blog_posts (
    id                     uuid primary key default gen_random_uuid(),
    slug                   varchar(255) not null unique,
    title                  varchar(500) not null,
    excerpt                varchar(1000),
    content_markdown       text not null default '',
    category               varchar(120),
    tags                   jsonb,
    status                 varchar(20) not null default 'draft'
                            check (status in ('draft','scheduled','published')),
    scheduled_for          timestamptz,
    published_at           timestamptz,
    cover_image_url        varchar(500),
    created_at             timestamptz not null default now(),
    updated_at             timestamptz not null default now()
);
create index if not exists ix_blog_posts_slug on blog_posts (slug);

-- ---------------------------------------------------------------------------
-- skills
-- ---------------------------------------------------------------------------
create table if not exists skills (
    id                     uuid primary key default gen_random_uuid(),
    name                   varchar(255) not null,
    category               varchar(60) not null
                            check (category in (
                                'programming_languages','frameworks','cloud','databases',
                                'cybersecurity','artificial_intelligence','operating_systems','tools'
                            )),
    proficiency_level      integer not null default 3 check (proficiency_level between 1 and 5),
    years_experience       double precision,
    display_order          integer not null default 0,
    created_at             timestamptz not null default now(),
    updated_at             timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- timeline_events
-- ---------------------------------------------------------------------------
create table if not exists timeline_events (
    id                     uuid primary key default gen_random_uuid(),
    title                  varchar(500) not null,
    description            text,
    event_type             varchar(30) not null
                            check (event_type in (
                                'education','award','research_milestone','internship',
                                'project','leadership','publication','scholarship'
                            )),
    event_date             date not null,
    photo_url              varchar(500),
    created_at             timestamptz not null default now(),
    updated_at             timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- achievements
-- ---------------------------------------------------------------------------
create table if not exists achievements (
    id                     uuid primary key default gen_random_uuid(),
    title                  varchar(500) not null,
    description            text,
    category               varchar(30) not null
                            check (category in
                                ('academic','competition','leadership','scholarship','certificate')),
    issuer                 varchar(255),
    date_awarded           date,
    certificate_file_id    uuid references file_assets(id),
    created_at             timestamptz not null default now(),
    updated_at             timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- gallery_items
-- ---------------------------------------------------------------------------
create table if not exists gallery_items (
    id                     uuid primary key default gen_random_uuid(),
    title                  varchar(500),
    description            text,
    category               varchar(30) not null
                            check (category in ('research','conference','project','laboratory')),
    image_url              varchar(500) not null,
    taken_at               date,
    created_at             timestamptz not null default now(),
    updated_at             timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- contact_messages
-- ---------------------------------------------------------------------------
create table if not exists contact_messages (
    id                     uuid primary key default gen_random_uuid(),
    name                   varchar(255) not null,
    email                  varchar(255) not null,
    subject                varchar(500),
    message                text not null,
    is_read                boolean not null default false,
    ip_address             varchar(64),
    created_at             timestamptz not null default now(),
    updated_at             timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- site_settings  (key/value store for Website Settings module)
-- ---------------------------------------------------------------------------
create table if not exists site_settings (
    key                    varchar(120) primary key,
    value                  jsonb,
    created_at             timestamptz not null default now(),
    updated_at             timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- audit_logs  (admin action history)
-- ---------------------------------------------------------------------------
create table if not exists audit_logs (
    id                     uuid primary key default gen_random_uuid(),
    admin_id               uuid references admins(id),
    action                 varchar(60) not null,
    entity_type            varchar(60) not null,
    entity_id              uuid,
    details                jsonb,
    ip_address             varchar(64),
    created_at             timestamptz not null default now()
);
create index if not exists ix_audit_logs_created_at on audit_logs (created_at desc);

-- ---------------------------------------------------------------------------
-- revoked_tokens  (JWT logout / revocation blocklist)
-- ---------------------------------------------------------------------------
create table if not exists revoked_tokens (
    id                     bigserial primary key,
    jti                    varchar(64) not null unique,
    revoked_at             timestamptz not null default now()
);
create index if not exists ix_revoked_tokens_jti on revoked_tokens (jti);

-- =============================================================================
-- Row Level Security — default deny on every table for Supabase's auto-API.
-- The Flask backend never uses the anon/authenticated Supabase roles; it
-- connects with the database owner role via DATABASE_URL, which is not
-- subject to RLS, so this has no effect on the Flask API's own behaviour.
-- =============================================================================
do $$
declare
    t text;
begin
    for t in
        select tablename from pg_tables
        where schemaname = 'public'
          and tablename in (
            'admins','research_projects','milestones','file_assets','publications',
            'software_projects','blog_posts','skills','timeline_events','achievements',
            'gallery_items','contact_messages','site_settings','audit_logs','revoked_tokens'
          )
    loop
        execute format('alter table %I enable row level security;', t);
    end loop;
end $$;
