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
end $$;
