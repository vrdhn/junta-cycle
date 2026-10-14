-- Migration: 20261014000003_checkouts_and_home_stand.sql
-- Description: Add home_parking_id & phone_number to profiles, and create checkouts table

-- 1. Extend profiles with home_parking_id and phone_number
alter table public.profiles
  add column if not exists home_parking_id uuid references public.parkings(id) on delete set null,
  add column if not exists phone_number text;

-- 2. Create checkouts table
create table if not exists public.checkouts (
  id uuid primary key default gen_random_uuid(),
  cycle_id uuid not null references public.cycles(id) on delete cascade,
  rider_id uuid not null references public.profiles(id) on delete cascade,
  home_parking_id uuid not null references public.parkings(id) on delete cascade,
  checked_out_at timestamptz not null default now(),
  returned_at timestamptz,
  status text not null default 'active' check (status in ('active', 'completed', 'cancelled')),
  return_parking_id uuid references public.parkings(id) on delete set null,
  return_note text,
  created_at timestamptz default now()
);

-- Index for quick lookup of active checkouts
create index if not exists idx_checkouts_active on public.checkouts (cycle_id) where status = 'active';
create index if not exists idx_checkouts_rider_active on public.checkouts (rider_id) where status = 'active';

-- Disable Row Level Security (application handles authorization in TypeScript)
alter table public.checkouts disable row level security;

-- Grants
grant usage on schema public to anon, authenticated, service_role;
grant all on public.checkouts to anon, authenticated, service_role;
