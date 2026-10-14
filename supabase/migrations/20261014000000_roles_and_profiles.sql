-- Migration: 20261014000000_roles_and_profiles.sql
-- Description: Roles, profiles, validation constraint, and signup trigger

-- 1. Allowed roles table
create table if not exists public.allowed_roles (
  role text primary key,
  description text,
  created_at timestamptz default now()
);

-- Seed predefined roles
insert into public.allowed_roles (role, description) values
  ('rider', 'Can find, unlock, ride, and return cycles'),
  ('manager', 'Can manage fleet, cycles, and view reports'),
  ('superuser', 'Full administrative system access')
on conflict (role) do nothing;

-- 2. Validation function to enforce roles against allowed_roles table
create or replace function public.validate_roles(p_roles text[])
returns boolean
language sql
stable
as $$
  select not exists (
    select unnest(p_roles)
    except
    select role from public.allowed_roles
  );
$$;

-- 3. Profiles table with roles array
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  full_name text,
  roles text[] not null default array['rider'],
  created_at timestamptz default now(),
  constraint valid_roles check (public.validate_roles(roles))
);

-- 4. Fast helper function for authorization checks
create or replace function public.has_role(check_role text)
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and (check_role = any(roles) or 'superuser' = any(roles))
  );
$$;

-- 5. Auto-create profile trigger on new user signup
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

-- 6. Enable Row Level Security (RLS)
alter table public.allowed_roles enable row level security;
alter table public.profiles enable row level security;

drop policy if exists "Anyone can read allowed roles" on public.allowed_roles;
create policy "Anyone can read allowed roles"
  on public.allowed_roles for select using (true);

drop policy if exists "Profiles are viewable by everyone" on public.profiles;
drop policy if exists "Users can read own profile or managers can read all" on public.profiles;
create policy "Profiles are viewable by everyone"
  on public.profiles for select using (true);

drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id);

-- 7. Grant access to PostgREST roles (anon, authenticated)
grant usage on schema public to anon, authenticated;
grant select on public.allowed_roles to anon, authenticated;
grant select, update on public.profiles to anon, authenticated;
