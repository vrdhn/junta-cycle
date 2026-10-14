-- Migration: 20261014000001_locations_and_parkings.sql
-- Description: Unified Place and Parking schema: City -> Place (Society / Landmark) -> Parking (Private / Public)

-- 1. Cities
create table if not exists public.cities (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  created_at timestamptz default now()
);

-- 2. Places (Societies and Landmarks belonging to a City)
create table if not exists public.places (
  id uuid primary key default gen_random_uuid(),
  city_id uuid not null references public.cities(id),
  name text not null,
  place_type text not null check (place_type in ('society', 'landmark')),
  created_at timestamptz default now(),
  unique(city_id, name)
);

-- 3. Parkings (Belongs to a Place, with optional manager for private parkings)
create table if not exists public.parkings (
  id uuid primary key default gen_random_uuid(),
  place_id uuid not null references public.places(id),
  name text not null,
  parking_type text not null check (parking_type in ('private', 'public')),
  manager_id uuid references public.profiles(id),
  capacity integer not null default 10,
  created_at timestamptz default now(),
  unique(place_id, name)
);

-- Disable Row Level Security (logic enforced in TypeScript application handlers)
alter table public.cities disable row level security;
alter table public.places disable row level security;
alter table public.parkings disable row level security;

-- Grants
grant usage on schema public to anon, authenticated, service_role;
grant all on public.cities to anon, authenticated, service_role;
grant all on public.places to anon, authenticated, service_role;
grant all on public.parkings to anon, authenticated, service_role;
