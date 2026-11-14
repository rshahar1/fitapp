-- Deletes are tombstones, win over later edits, cascade to children, and catch late children (FR-016, FR-017).

set role authenticated;
select t_as('00000000-0000-0000-0000-00000000000a');

insert into workouts (id, started_at, updated_at)
  values ('30000000-0000-4000-8000-000000000001', now(), '2026-11-14T10:00:00Z');
insert into workout_exercises (id, workout_id, exercise_id, position, updated_at)
  values ('31000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000001',
          '00000000-0000-4000-8000-000000000001', 0, '2026-11-14T10:00:00Z');
insert into sets (id, workout_exercise_id, set_no, weight, reps, is_overload, completed_at, updated_at)
  values ('32000000-0000-4000-8000-000000000001', '31000000-0000-4000-8000-000000000001',
          1, 60, 8, false, now(), '2026-11-14T10:00:00Z');
insert into templates (id, name, created_at, updated_at)
  values ('20000000-0000-4000-8000-000000000001', 'Push', now(), '2026-11-14T10:00:00Z');
insert into template_exercises (id, template_id, exercise_id, position, updated_at)
  values ('21000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001',
          '00000000-0000-4000-8000-000000000001', 0, '2026-11-14T10:00:00Z');

do $$
declare
  r jsonb;
  cursor_before timestamptz;
begin
  cursor_before := (select server_updated_at from sets);

  -- Delete the workout and the template.
  r := sync_push(jsonb_build_object('deletes', jsonb_build_array(
         jsonb_build_object('table', 'workouts', 'id', '30000000-0000-4000-8000-000000000001'),
         jsonb_build_object('table', 'templates', 'id', '20000000-0000-4000-8000-000000000001'),
         jsonb_build_object('table', 'sets', 'id', '99999999-0000-4000-8000-000000000000'))));
  assert jsonb_array_length(r -> 'rejected') = 0, 'unknown id delete is a no-op: ' || r::text;

  assert (select deleted_at from workouts) is not null, 'workout tombstoned, not removed';
  assert (select deleted_at from workout_exercises) is not null, 'cascade to workout_exercises';
  assert (select deleted_at from sets) is not null, 'cascade through to sets';
  assert (select server_updated_at from sets) > cursor_before, 'cascaded rows get a new cursor';
  assert (select deleted_at from template_exercises) is not null, 'cascade to template_exercises';

  -- An edit with a newer timestamp (offline device) never resurrects it.
  r := sync_push(jsonb_build_object('upserts', jsonb_build_object('workouts', jsonb_build_array(
         jsonb_build_object('id', '30000000-0000-4000-8000-000000000001', 'started_at', now(),
                            'notes', 'edited offline', 'updated_at', '2030-01-01T00:00:00Z')))));
  assert jsonb_array_length(r -> 'rejected') = 0, r::text;
  assert (select deleted_at from workouts) is not null, 'delete wins';
  assert (select notes from workouts) is null, 'edit ignored';

  -- A child pushed later under the deleted parent arrives tombstoned.
  r := sync_push(jsonb_build_object('upserts', jsonb_build_object('sets', jsonb_build_array(
         jsonb_build_object('id', '32000000-0000-4000-8000-000000000002',
           'workout_exercise_id', '31000000-0000-4000-8000-000000000001', 'set_no', 2, 'weight', 60,
           'reps', 8, 'is_overload', false, 'completed_at', now(), 'updated_at', now())))));
  assert jsonb_array_length(r -> 'rejected') = 0, r::text;
  assert (select deleted_at from sets where id = '32000000-0000-4000-8000-000000000002') is not null,
    'late child of a tombstoned parent is tombstoned';

  -- A cleared and re-logged set (new id, same set_no) coexists with its tombstone.
  r := sync_push(jsonb_build_object('upserts', jsonb_build_object(
         'workouts', jsonb_build_array(jsonb_build_object('id', '30000000-0000-4000-8000-000000000002',
           'started_at', now(), 'updated_at', now())),
         'workout_exercises', jsonb_build_array(jsonb_build_object('id', '31000000-0000-4000-8000-000000000002',
           'workout_id', '30000000-0000-4000-8000-000000000002', 'exercise_id', '00000000-0000-4000-8000-000000000001',
           'position', 0, 'updated_at', now())),
         'sets', jsonb_build_array(jsonb_build_object('id', '32000000-0000-4000-8000-000000000003',
           'workout_exercise_id', '31000000-0000-4000-8000-000000000002', 'set_no', 1, 'weight', 60,
           'reps', 8, 'is_overload', false, 'completed_at', now(), 'updated_at', now())))));
  r := sync_push(jsonb_build_object(
         'deletes', jsonb_build_array(jsonb_build_object('table', 'sets', 'id', '32000000-0000-4000-8000-000000000003')),
         'upserts', jsonb_build_object('sets', jsonb_build_array(jsonb_build_object(
           'id', '32000000-0000-4000-8000-000000000004',
           'workout_exercise_id', '31000000-0000-4000-8000-000000000002', 'set_no', 1, 'weight', 62.5,
           'reps', 8, 'is_overload', true, 'completed_at', now(), 'updated_at', now())))));
  assert jsonb_array_length(r -> 'rejected') = 0, r::text;
  assert (select count(*) from sets where workout_exercise_id = '31000000-0000-4000-8000-000000000002'
          and deleted_at is null) = 1, 'exactly one live set 1';
end $$;
reset role;
