-- junta-cycle Demo Seed Data
-- 10 Indian-named users in alphabetical order (A through J)
-- Roles distribution: 1 superuser, 3 managers, 9 riders
-- Default Password for all demo users: junta123

do $$
declare
  user_rec record;
  new_user_id uuid;
  id_type text;
  default_pw text := 'junta123';
  encrypted_pw text;
  blr_id uuid;
  pune_id uuid;
  soc1_id uuid;
  soc2_id uuid;
  soc3_id uuid;
  lm1_id uuid;
  lm2_id uuid;
  mgr_bhavna uuid;
  mgr_chirag uuid;
  mgr_divya uuid;
  park_tower_a uuid;
  park_clubhouse uuid;
  park_sector2 uuid;
begin
  execute 'create extension if not exists pgcrypto with schema extensions';
  encrypted_pw := extensions.crypt(default_pw, extensions.gen_salt('bf'));

  for user_rec in
    select * from (values
      ('aarav@junta.cycle', 'Aarav Patel', array['superuser']),
      ('bhavna@junta.cycle', 'Bhavna Sharma', array['manager', 'rider']),
      ('chirag@junta.cycle', 'Chirag Gupta', array['manager', 'rider']),
      ('divya@junta.cycle', 'Divya Nair', array['manager', 'rider']),
      ('eshan@junta.cycle', 'Eshan Reddy', array['rider']),
      ('fatima@junta.cycle', 'Fatima Khan', array['rider']),
      ('gopal@junta.cycle', 'Gopal Krishnan', array['rider']),
      ('hema@junta.cycle', 'Hema Sundaram', array['rider']),
      ('ishan@junta.cycle', 'Ishan Joshi', array['rider']),
      ('jaya@junta.cycle', 'Jaya Verma', array['rider'])
    ) as t(email, full_name, roles)
  loop
    -- Check if user already exists in auth.users
    select id into new_user_id from auth.users where email = user_rec.email;

    if new_user_id is null then
      new_user_id := gen_random_uuid();

      insert into auth.users (
        instance_id,
        id,
        aud,
        role,
        email,
        encrypted_password,
        email_confirmed_at,
        raw_app_meta_data,
        raw_user_meta_data,
        created_at,
        updated_at,
        confirmation_token,
        email_change,
        email_change_token_new,
        recovery_token
      ) values (
        '00000000-0000-0000-0000-000000000000',
        new_user_id,
        'authenticated',
        'authenticated',
        user_rec.email,
        encrypted_pw,
        now(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        jsonb_build_object('full_name', user_rec.full_name),
        now(),
        now(),
        '',
        '',
        '',
        ''
      );

      select data_type into id_type from information_schema.columns
      where table_schema = 'auth' and table_name = 'identities' and column_name = 'id';

      if exists (
        select 1 from information_schema.columns
        where table_schema = 'auth' and table_name = 'identities' and column_name = 'provider_id'
      ) then
        if id_type = 'uuid' then
          execute 'insert into auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at) values ($1, $2, $3, $4, $5, now(), now(), now()) on conflict do nothing'
          using new_user_id, new_user_id, jsonb_build_object('sub', new_user_id::text, 'email', user_rec.email), 'email', new_user_id::text;
        else
          execute 'insert into auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at) values ($1, $2, $3, $4, $5, now(), now(), now()) on conflict do nothing'
          using new_user_id::text, new_user_id, jsonb_build_object('sub', new_user_id::text, 'email', user_rec.email), 'email', new_user_id::text;
        end if;
      else
        if id_type = 'uuid' then
          execute 'insert into auth.identities (id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at) values ($1, $2, $3, $4, now(), now(), now()) on conflict do nothing'
          using new_user_id, new_user_id, jsonb_build_object('sub', new_user_id::text, 'email', user_rec.email), 'email';
        else
          execute 'insert into auth.identities (id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at) values ($1, $2, $3, $4, now(), now(), now()) on conflict do nothing'
          using new_user_id::text, new_user_id, jsonb_build_object('sub', new_user_id::text, 'email', user_rec.email), 'email';
        end if;
      end if;

    else
      -- Update existing user password and metadata
      update auth.users
      set encrypted_password = encrypted_pw,
          raw_user_meta_data = jsonb_build_object('full_name', user_rec.full_name),
          updated_at = now()
      where id = new_user_id;
    end if;

    -- Upsert profile with full_name and specific roles
    insert into public.profiles (id, email, full_name, roles)
    values (new_user_id, user_rec.email, user_rec.full_name, user_rec.roles)
    on conflict (id) do update
    set email = excluded.email,
        full_name = excluded.full_name,
        roles = excluded.roles;

  end loop;

  -- Look up managers for private parkings
  select id into mgr_bhavna from public.profiles where email = 'bhavna@junta.cycle';
  select id into mgr_chirag from public.profiles where email = 'chirag@junta.cycle';
  select id into mgr_divya from public.profiles where email = 'divya@junta.cycle';

  -- Seed Cities
  insert into public.cities (name) values ('Bengaluru')
  on conflict (name) do update set name = excluded.name returning id into blr_id;

  insert into public.cities (name) values ('Pune')
  on conflict (name) do update set name = excluded.name returning id into pune_id;

  -- Seed Places
  insert into public.places (city_id, name) values (blr_id, 'Palm Meadows')
  on conflict (city_id, name) do update set name = excluded.name returning id into soc1_id;

  insert into public.places (city_id, name) values (blr_id, 'Green Glen Layout')
  on conflict (city_id, name) do update set name = excluded.name returning id into soc2_id;

  insert into public.places (city_id, name) values (pune_id, 'Amanora Park Town')
  on conflict (city_id, name) do update set name = excluded.name returning id into soc3_id;

  insert into public.places (city_id, name) values (blr_id, 'Indiranagar Metro Station')
  on conflict (city_id, name) do update set name = excluded.name returning id into lm1_id;

  insert into public.places (city_id, name) values (blr_id, 'Koramangala Sony World Signal')
  on conflict (city_id, name) do update set name = excluded.name returning id into lm2_id;

  -- Seed Private Parkings (Belongs to Society with Assigned Manager)
  insert into public.parkings (place_id, name, parking_type, manager_id, capacity)
  values (soc1_id, 'Tower A Cycle Rack', 'private', mgr_bhavna, 12)
  on conflict (place_id, name) do update set capacity = excluded.capacity, manager_id = excluded.manager_id
  returning id into park_tower_a;

  insert into public.parkings (place_id, name, parking_type, manager_id, capacity)
  values (soc2_id, 'Clubhouse Stand', 'private', mgr_chirag, 8)
  on conflict (place_id, name) do update set capacity = excluded.capacity, manager_id = excluded.manager_id
  returning id into park_clubhouse;

  insert into public.parkings (place_id, name, parking_type, manager_id, capacity)
  values (soc3_id, 'Sector 2 Basement Rack', 'private', mgr_divya, 15)
  on conflict (place_id, name) do update set capacity = excluded.capacity, manager_id = excluded.manager_id
  returning id into park_sector2;

  -- Seed Public Parkings (Belongs to Landmark)
  insert into public.parkings (place_id, name, parking_type, capacity)
  values (lm1_id, 'Metro Gate 1 Rack', 'public', 20)
  on conflict (place_id, name) do update set capacity = excluded.capacity;

  insert into public.parkings (place_id, name, parking_type, capacity)
  values (lm2_id, 'Sony World Footpath Stand', 'public', 10)
  on conflict (place_id, name) do update set capacity = excluded.capacity;

  -- Seed Cycles for Private Parking Stands (Tower A: Bhavna, Clubhouse: Chirag, Sector 2: Divya)
  insert into public.cycles (cycle_number, qr_id, lock_code, parking_id, company_name, color, model_number, status) values
    ('JC-101', '11111111-1111-1111-1111-111111111101', '4821', park_tower_a, 'Hero Cycles', 'Matte Black', 'Sprint Pro 27.5', 'running'),
    ('JC-102', '11111111-1111-1111-1111-111111111102', '3912', park_tower_a, 'Hercules', 'Neon Blue', 'Roadeo Hardtail', 'running'),
    ('JC-103', '11111111-1111-1111-1111-111111111103', '7744', park_tower_a, 'Decathlon Btwin', 'Flame Orange', 'Rockrider ST30', 'puncture'),
    ('JC-104', '11111111-1111-1111-1111-111111111104', '9103', park_tower_a, 'Firefox', 'Pearl White', 'Target 29 D', 'broken'),
    ('JC-105', '11111111-1111-1111-1111-111111111105', '6219', park_tower_a, 'Trek', 'Forest Green', 'Marlin 4 Gen 2', 'running'),

    ('JC-201', '22222222-2222-2222-2222-222222222201', '5120', park_clubhouse, 'Hero Lectro', 'Metallic Silver', 'C6 E-Cycle', 'running'),
    ('JC-202', '22222222-2222-2222-2222-222222222202', '8341', park_clubhouse, 'Hercules', 'Royal Red', 'Street Cat Pro', 'running'),
    ('JC-203', '22222222-2222-2222-2222-222222222203', '2490', park_clubhouse, 'Decathlon Btwin', 'Dark Grey', 'Riverside 120', 'running'),
    ('JC-204', '22222222-2222-2222-2222-222222222204', '1899', park_clubhouse, 'Firefox', 'Electric Yellow', 'Sniper 21S', 'puncture'),

    ('JC-301', '33333333-3333-3333-3333-333333333301', '6620', park_sector2, 'Hero Cycles', 'Sky Blue', 'Sprint Next D', 'running'),
    ('JC-302', '33333333-3333-3333-3333-333333333302', '4109', park_sector2, 'Hercules', 'Matte Green', 'Storm City Commute', 'running'),
    ('JC-303', '33333333-3333-3333-3333-333333333303', '7531', park_sector2, 'Decathlon Btwin', 'Crimson Red', 'MyBike 700 V2', 'broken')
  on conflict (cycle_number) do update set
    qr_id = excluded.qr_id,
    lock_code = excluded.lock_code,
    parking_id = excluded.parking_id,
    company_name = excluded.company_name,
    color = excluded.color,
    model_number = excluded.model_number,
    status = excluded.status;

end $$;
