-- Feature 013: sync rules enforced by the server (data-model.md §3).

-- Last-writer-wins on the client `updated_at`, deletes win, ownership is immutable,
-- and every accepted write gets a fresh pull cursor.
create or replace function public.sync_guard() returns trigger
language plpgsql set search_path = public, pg_temp as $$
begin
  if tg_op = 'UPDATE' then
    if old.deleted_at is not null then
      return null;                                   -- tombstoned: ignore every later write
    end if;
    if new.deleted_at is null and new.updated_at < old.updated_at then
      return null;                                   -- older edit loses
    end if;
    new.user_id := old.user_id;
  end if;
  new.server_updated_at := clock_timestamp();
  return new;
end $$;

-- A child that arrives under an already tombstoned parent is tombstoned too.
-- tg_argv: [0] parent table, [1] FK column on the child.
create or replace function public.sync_child_of_tombstone() returns trigger
language plpgsql set search_path = public, pg_temp as $$
declare
  parent_deleted timestamptz;
begin
  execute format('select deleted_at from public.%I where id = $1', tg_argv[0])
    into parent_deleted
    using (to_jsonb(new) ->> tg_argv[1])::uuid;
  if parent_deleted is not null and new.deleted_at is null then
    new.deleted_at := parent_deleted;
  end if;
  return new;
end $$;

-- Tombstoning a parent tombstones its children (which cascade further via their own trigger).
-- tg_argv: [0] child table, [1] FK column on the child.
create or replace function public.sync_cascade_tombstone() returns trigger
language plpgsql set search_path = public, pg_temp as $$
begin
  if old.deleted_at is null and new.deleted_at is not null then
    execute format(
      'update public.%I set deleted_at = $1 where %I = $2 and deleted_at is null',
      tg_argv[0], tg_argv[1])
      using new.deleted_at, new.id;
  end if;
  return null;
end $$;

-- Guards on every synced table. Named with a "b_" prefix so the "a_" child trigger runs first.
create trigger b_sync_guard before insert or update on public.custom_exercises
  for each row execute function public.sync_guard();
create trigger b_sync_guard before insert or update on public.exercise_overrides
  for each row execute function public.sync_guard();
create trigger b_sync_guard before insert or update on public.exercise_state
  for each row execute function public.sync_guard();
create trigger b_sync_guard before insert or update on public.templates
  for each row execute function public.sync_guard();
create trigger b_sync_guard before insert or update on public.template_exercises
  for each row execute function public.sync_guard();
create trigger b_sync_guard before insert or update on public.workouts
  for each row execute function public.sync_guard();
create trigger b_sync_guard before insert or update on public.workout_exercises
  for each row execute function public.sync_guard();
create trigger b_sync_guard before insert or update on public.sets
  for each row execute function public.sync_guard();
create trigger b_sync_guard before insert or update on public.activities
  for each row execute function public.sync_guard();
create trigger b_sync_guard before insert or update on public.user_settings
  for each row execute function public.sync_guard();

create trigger a_sync_child_of_tombstone before insert on public.template_exercises
  for each row execute function public.sync_child_of_tombstone('templates', 'template_id');
create trigger a_sync_child_of_tombstone before insert on public.workout_exercises
  for each row execute function public.sync_child_of_tombstone('workouts', 'workout_id');
create trigger a_sync_child_of_tombstone before insert on public.sets
  for each row execute function public.sync_child_of_tombstone('workout_exercises', 'workout_exercise_id');

create trigger sync_cascade_tombstone after update of deleted_at on public.templates
  for each row execute function public.sync_cascade_tombstone('template_exercises', 'template_id');
create trigger sync_cascade_tombstone after update of deleted_at on public.workouts
  for each row execute function public.sync_cascade_tombstone('workout_exercises', 'workout_id');
create trigger sync_cascade_tombstone after update of deleted_at on public.workout_exercises
  for each row execute function public.sync_cascade_tombstone('sets', 'workout_exercise_id');
