-- Migration: 20261014000002_cycles.sql
-- Description: Cycles table belonging to a private parking stand with QR UUID and lock code

create table if not exists public.cycles (
  id uuid primary key default gen_random_uuid(),
  parking_id uuid not null references public.parkings(id) on delete cascade,
  cycle_number text not null unique,
  qr_id uuid not null default gen_random_uuid() unique,
  lock_code text not null default '1234',
  company_name text not null,
  color text not null,
  model_number text not null,
  status text not null default 'running' check (status in ('running', 'broken', 'puncture', 'maintenance')),
  created_at timestamptz default now()
);

-- Disable Row Level Security (logic enforced in TypeScript application handlers)
alter table public.cycles disable row level security;

-- Grants
grant usage on schema public to anon, authenticated, service_role;
grant all on public.cycles to anon, authenticated, service_role;
