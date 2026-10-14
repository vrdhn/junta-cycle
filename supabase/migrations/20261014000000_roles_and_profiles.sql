-- Migration: 20261014000000_roles_and_profiles.sql
-- Description: Minimal relational schema for roles and user profiles (No RLS, logic handled in TypeScript)

-- 1. Allowed roles reference table
create table if not exists public.allowed_roles (
  role text primary key,
  created_at timestamptz default now()
);

-- Seed predefined roles
insert into public.allowed_roles (role) values
  ('rider'),
  ('manager'),
  ('superuser')
on conflict (role) do nothing;

-- 2. User profiles table (1-to-1 extension of auth.users)
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  full_name text,
  roles text[] not null default array['rider'],
  created_at timestamptz default now()
);

-- 3. Simple profile creation hook on user signup
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
as $$
begin
  insert into public.profiles (id, email, roles)
  values (new.id, new.email, array['rider'])
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 4. Disable Row Level Security (RLS) - business authorization handled in TypeScript handlers
alter table public.allowed_roles disable row level security;
alter table public.profiles disable row level security;

-- 5. Standard access grants
grant usage on schema public to anon, authenticated, service_role;
grant all on public.allowed_roles to anon, authenticated, service_role;
grant all on public.profiles to anon, authenticated, service_role;
