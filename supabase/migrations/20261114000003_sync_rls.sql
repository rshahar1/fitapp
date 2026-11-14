-- Feature 013: owner-only access on every synced table (data-model.md §4).
-- Supabase grants all table privileges to anon/authenticated by default; reset them explicitly.

do $$
declare
  t text;
begin
  foreach t in array array[
    'custom_exercises', 'exercise_overrides', 'exercise_state', 'templates', 'template_exercises',
    'workouts', 'workout_exercises', 'sets', 'activities', 'user_settings'
  ] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('alter table public.%I force row level security', t);
    execute format('revoke all on table public.%I from anon, authenticated', t);
    execute format('grant select, insert, update on table public.%I to authenticated', t);
    execute format(
      'create policy owner_all on public.%I for all to authenticated '
      'using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()))', t);
  end loop;
end $$;
