-- Size and range limits: one account cannot fill the database with oversized rows. Limits sit well above
-- anything the app can produce, so real data is never rejected.

set role authenticated;
select t_as('00000000-0000-0000-0000-00000000000a');

do $$
declare
  r jsonb;
  big_route text := repeat('a', 1000001);
  ok_route text := repeat('a', 200000);
begin
  -- Realistic rows pass.
  r := sync_push(jsonb_build_object('upserts', jsonb_build_object(
    'activities', jsonb_build_array(jsonb_build_object('id', '40000000-0000-4000-8000-000000000001',
      'type_id', 'cycling', 'started_at', now(), 'duration_minutes', 1440, 'distance_meters', 300000,
      'notes', repeat('n', 200), 'source', 'gps', 'route', ok_route, 'splits', repeat('1', 5000),
      'updated_at', now())),
    'workouts', jsonb_build_array(jsonb_build_object('id', '30000000-0000-4000-8000-000000000001',
      'started_at', now(), 'notes', repeat('w', 5000), 'updated_at', now())),
    'user_settings', jsonb_build_array(jsonb_build_object(
      'data', '{"default_rest_seconds": 90, "rest_alert_haptic": true, "rest_alert_sound": false}'::jsonb,
      'updated_at', now())))));
  assert jsonb_array_length(r -> 'rejected') = 0, 'realistic rows pass: ' || r::text;

  -- Oversized or out-of-range rows are rejected one by one.
  r := sync_push(jsonb_build_object('upserts', jsonb_build_object(
    'activities', jsonb_build_array(
      jsonb_build_object('id', '40000000-0000-4000-8000-000000000002', 'type_id', 'cycling',
        'started_at', now(), 'source', 'gps', 'route', big_route, 'updated_at', now()),
      jsonb_build_object('id', '40000000-0000-4000-8000-000000000003', 'type_id', repeat('t', 100),
        'started_at', now(), 'source', 'manual', 'updated_at', now()),
      jsonb_build_object('id', '40000000-0000-4000-8000-000000000004', 'type_id', 'running',
        'started_at', now(), 'source', 'manual', 'notes', repeat('n', 1001), 'updated_at', now())),
    'workouts', jsonb_build_array(jsonb_build_object('id', '30000000-0000-4000-8000-000000000002',
      'started_at', now(), 'notes', repeat('w', 10001), 'updated_at', now())),
    'user_settings', jsonb_build_array(jsonb_build_object(
      'data', jsonb_build_object('junk', repeat('x', 5000)), 'updated_at', now() + interval '1 hour')))));
  assert jsonb_array_length(r -> 'rejected') = 5, 'five oversized rows rejected: ' || r::text;

  -- Numeric ranges.
  r := sync_push(jsonb_build_object('upserts', jsonb_build_object(
    'workout_exercises', jsonb_build_array(jsonb_build_object('id', '31000000-0000-4000-8000-000000000001',
      'workout_id', '30000000-0000-4000-8000-000000000001', 'exercise_id', '00000000-0000-4000-8000-000000000001',
      'position', 0, 'updated_at', now())),
    'sets', jsonb_build_array(
      jsonb_build_object('id', '32000000-0000-4000-8000-000000000001',
        'workout_exercise_id', '31000000-0000-4000-8000-000000000001', 'set_no', 1, 'weight', 2001, 'reps', 5,
        'is_overload', false, 'completed_at', now(), 'updated_at', now()),
      jsonb_build_object('id', '32000000-0000-4000-8000-000000000002',
        'workout_exercise_id', '31000000-0000-4000-8000-000000000001', 'set_no', 2, 'weight', 100, 'reps', 10001,
        'is_overload', false, 'completed_at', now(), 'updated_at', now()),
      jsonb_build_object('id', '32000000-0000-4000-8000-000000000003',
        'workout_exercise_id', '31000000-0000-4000-8000-000000000001', 'set_no', 3, 'weight', 300, 'reps', 5,
        'is_overload', true, 'completed_at', now(), 'updated_at', now())))));
  assert jsonb_array_length(r -> 'rejected') = 2, 'two out-of-range sets rejected: ' || r::text;
  assert (select count(*) from sets) = 1, 'the valid set is stored';
end $$;
reset role;

-- Feature 017: snowboarding columns are bounded.
set role authenticated;
select t_as('00000000-0000-0000-0000-00000000000a');

do $$
declare
  r jsonb;
begin
  r := sync_push(jsonb_build_object('upserts', jsonb_build_object('activities', jsonb_build_array(
    jsonb_build_object('id', '40000000-0000-4000-8000-000000000201', 'type_id', 'snowboarding',
      'started_at', now(), 'source', 'gps', 'segments', repeat('s', 300000), 'run_count', 5, 'updated_at', now()),
    jsonb_build_object('id', '40000000-0000-4000-8000-000000000202', 'type_id', 'snowboarding',
      'started_at', now(), 'source', 'gps', 'segments', repeat('s', 300001), 'updated_at', now()),
    jsonb_build_object('id', '40000000-0000-4000-8000-000000000203', 'type_id', 'snowboarding',
      'started_at', now(), 'source', 'gps', 'run_count', -1, 'updated_at', now())))));
  assert (r ->> 'applied')::int = 1, 'only the valid snowboard row applied: ' || r::text;
  assert jsonb_array_length(r -> 'rejected') = 2, 'oversized segments and negative run_count rejected: ' || r::text;
end $$;
reset role;
