-- sync_push contract: FK ordering inside one call, per-row rejection, counts (contracts/sync-backend.md).

set role authenticated;
select t_as('00000000-0000-0000-0000-00000000000a');

do $$
declare
  r jsonb;
begin
  -- Children listed before parents in the JSON still apply: the function uses FK order.
  r := sync_push(jsonb_build_object('upserts', jsonb_build_object(
    'sets', jsonb_build_array(jsonb_build_object('id', '32000000-0000-4000-8000-000000000001',
      'workout_exercise_id', '31000000-0000-4000-8000-000000000001', 'set_no', 1, 'weight', 60, 'reps', 8,
      'is_overload', false, 'completed_at', '2026-11-14T10:05:00Z', 'updated_at', '2026-11-14T10:05:00Z')),
    'workout_exercises', jsonb_build_array(jsonb_build_object('id', '31000000-0000-4000-8000-000000000001',
      'workout_id', '30000000-0000-4000-8000-000000000001', 'exercise_id', '10000000-0000-4000-8000-000000000001',
      'position', 0, 'plan_base_weight', 57.5, 'result_base_weight', 60, 'updated_at', '2026-11-14T10:05:00Z')),
    'workouts', jsonb_build_array(jsonb_build_object('id', '30000000-0000-4000-8000-000000000001',
      'started_at', '2026-11-14T10:00:00Z', 'ended_at', '2026-11-14T11:00:00Z', 'updated_at', '2026-11-14T11:00:00Z')),
    'custom_exercises', jsonb_build_array(jsonb_build_object('id', '10000000-0000-4000-8000-000000000001',
      'name', 'Zercher squat', 'is_per_hand', false, 'default_increment', 2.5, 'archived_at', null,
      'updated_at', '2026-11-14T09:00:00Z')),
    'activities', jsonb_build_array(jsonb_build_object('id', '40000000-0000-4000-8000-000000000001',
      'type_id', 'running', 'started_at', '2026-11-13T07:00:00Z', 'duration_minutes', 30,
      'distance_meters', 5000, 'source', 'gps', 'route', '_p~iF~ps|U_ulLnnqC', 'splits', '[300]',
      'updated_at', '2026-11-13T07:30:00Z')),
    'user_settings', jsonb_build_array(jsonb_build_object(
      'data', '{"default_rest_seconds": 120, "rest_alert_sound": false}'::jsonb,
      'updated_at', '2026-11-14T08:00:00Z')),
    -- Bad rows: CHECK violation, FK to a missing parent, missing NOT NULL.
    'templates', jsonb_build_array(jsonb_build_object('id', '20000000-0000-4000-8000-000000000001',
      'name', '', 'created_at', now(), 'updated_at', now())),
    'template_exercises', jsonb_build_array(jsonb_build_object('id', '21000000-0000-4000-8000-000000000001',
      'template_id', '29999999-0000-4000-8000-000000000000', 'exercise_id', '00000000-0000-4000-8000-000000000001',
      'position', 0, 'updated_at', now())),
    'exercise_state', jsonb_build_array(jsonb_build_object('exercise_id', '00000000-0000-4000-8000-000000000001',
      'base_weight', null, 'target_reps', 8, 'target_sets', 3, 'increment', 2.5, 'updated_at', now())))));

  assert (r ->> 'applied')::int = 6, 'six good rows applied: ' || r::text;
  assert jsonb_array_length(r -> 'rejected') = 3, 'three bad rows rejected: ' || r::text;
  assert (r -> 'rejected') @> '[{"table":"templates","id":"20000000-0000-4000-8000-000000000001"}]', r::text;
  assert (r -> 'rejected') @> '[{"table":"exercise_state","id":"00000000-0000-4000-8000-000000000001"}]', r::text;

  assert (select count(*) from sets) = 1, 'set stored';
  assert (select result_base_weight from workout_exercises) = 60, 'snapshot stored';
  assert (select route from activities) = '_p~iF~ps|U_ulLnnqC', 'route stored';
  assert (select (data ->> 'default_rest_seconds')::int from user_settings) = 120, 'settings stored';

  -- Deleting a composite-key table is refused per row, not per call.
  r := sync_push(jsonb_build_object('deletes', jsonb_build_array(
         jsonb_build_object('table', 'exercise_state', 'id', '00000000-0000-4000-8000-000000000001'),
         jsonb_build_object('table', 'activities', 'id', '40000000-0000-4000-8000-000000000001'))));
  assert (r ->> 'applied')::int = 1 and jsonb_array_length(r -> 'rejected') = 1, r::text;

  -- Client-sent bookkeeping is ignored.
  r := sync_push(jsonb_build_object('upserts', jsonb_build_object('workouts', jsonb_build_array(
         jsonb_build_object('id', '30000000-0000-4000-8000-000000000009', 'started_at', now(), 'updated_at', now(),
           'deleted_at', now(), 'user_id', '00000000-0000-0000-0000-00000000000b',
           'server_updated_at', '2000-01-01T00:00:00Z')))));
  assert jsonb_array_length(r -> 'rejected') = 0, r::text;
  assert (select deleted_at from workouts where id = '30000000-0000-4000-8000-000000000009') is null, 'deleted_at ignored';
  assert (select user_id from workouts where id = '30000000-0000-4000-8000-000000000009')
         = '00000000-0000-0000-0000-00000000000a', 'user_id ignored';
  assert (select server_updated_at from workouts where id = '30000000-0000-4000-8000-000000000009')
         > '2020-01-01', 'server_updated_at ignored';
end $$;
reset role;
