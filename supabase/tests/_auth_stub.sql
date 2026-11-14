-- Minimal stand-in for the parts of Supabase the migrations rely on, so they run on plain Postgres (PGlite).
-- Not deployed. Users A and B are fixed test accounts.

create role anon nologin;
create role authenticated nologin;
grant usage on schema public to anon, authenticated;

create schema auth;
grant usage on schema auth to anon, authenticated;

create table auth.users (id uuid primary key);

-- Same contract as Supabase: the caller's id from the JWT claim, NULL when anonymous.
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;

insert into auth.users (id) values
  ('00000000-0000-0000-0000-00000000000a'),
  ('00000000-0000-0000-0000-00000000000b');

-- Test helpers (run as superuser before `set role`).
create function public.t_as(uid uuid) returns void language sql as $$
  select set_config('request.jwt.claim.sub', coalesce(uid::text, ''), false)
$$;
grant execute on function public.t_as(uuid) to anon, authenticated;
