-- ESupabaseAnalytics — analytics events table
--
-- Run this once in each Supabase project that will receive events. The table
-- name below must match `ESupabaseAnalyticsConfig.tableName` in your app
-- (default `"analytics"`).

create extension if not exists "pgcrypto";

create table if not exists public.analytics (
  id              uuid primary key default gen_random_uuid(),
  occurred_at     timestamptz not null,
  received_at     timestamptz not null default now(),
  event_name      text not null,
  user_id         text,
  device_id       text not null,
  icloud_id       text,
  session_id      uuid not null,
  platform        text not null check (platform in ('ios','android')),
  os_version      text,
  device_model    text,
  app_version     text,
  app_build       text,
  locale          text,
  timezone        text,
  is_debug        boolean,
  screen_name     text,
  properties      jsonb
);

create index if not exists analytics_device_occurred_idx
  on public.analytics (device_id, occurred_at desc);

create index if not exists analytics_user_occurred_idx
  on public.analytics (user_id, occurred_at desc)
  where user_id is not null;

create index if not exists analytics_event_occurred_idx
  on public.analytics (event_name, occurred_at desc);

alter table public.analytics enable row level security;

-- anon + authenticated clients may insert; no SELECT / UPDATE / DELETE from the app.
-- Read via the service role (dashboard, backend, warehouse).
drop policy if exists "esupabaseanalytics_insert" on public.analytics;
create policy "esupabaseanalytics_insert"
  on public.analytics
  for insert
  to anon, authenticated
  with check (true);
