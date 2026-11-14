-- Owner-only access (FR-005, SC-006). A = ...0a, B = ...0b.

-- A writes one row into every table.
set role authenticated;
select t_as('00000000-0000-0000-0000-00000000000a');

insert into custom_exercises (id, name, is_per_hand, default_increment, updated_at)
  values ('10000000-0000-4000-8000-000000000001', 'Zercher squat', false, 2.5, now());
insert into exercise_overrides (exercise_id, archived_at, updated_at)
  values ('00000000-0000-4000-8000-000000000001', now(), now());
insert into exercise_state (exercise_id, base_weight, target_reps, target_sets, increment, updated_at)
  values ('00000000-0000-4000-8000-000000000001', 60, 8, 3, 2.5, now());
insert into templates (id, name, created_at, updated_at)
  values ('20000000-0000-4000-8000-000000000001', 'Push', now(), now());
insert into template_exercises (id, template_id, exercise_id, position, updated_at)
  values ('21000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001',
          '00000000-0000-4000-8000-000000000001', 0, now());
insert into workouts (id, started_at, updated_at)
  values ('30000000-0000-4000-8000-000000000001', now(), now());
insert into workout_exercises (id, workout_id, exercise_id, position, updated_at)
  values ('31000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000001',
          '00000000-0000-4000-8000-000000000001', 0, now());
insert into sets (id, workout_exercise_id, set_no, weight, reps, is_overload, completed_at, updated_at)
  values ('32000000-0000-4000-8000-000000000001', '31000000-0000-4000-8000-000000000001',
          1, 60, 8, false, now(), now());
insert into activities (id, type_id, started_at, updated_at)
  values ('40000000-0000-4000-8000-000000000001', 'running', now(), now());
insert into user_settings (data, updated_at) values ('{"default_rest_seconds": 90}', now());

do $$
begin
  assert (select count(*) from sets) = 1, 'A sees own set';
  assert (select user_id from workouts) = '00000000-0000-0000-0000-00000000000a', 'user_id defaults to caller';
end $$;

-- B sees and changes nothing of A's.
select t_as('00000000-0000-0000-0000-00000000000b');
do $$
declare
  t text;
  n bigint;
begin
  foreach t in array array['custom_exercises','exercise_overrides','exercise_state','templates',
      'template_exercises','workouts','workout_exercises','sets','activities','user_settings'] loop
    execute format('select count(*) from %I', t) into n;
    assert n = 0, format('B must not see %s (saw %s)', t, n);
  end loop;
  update workouts set notes = 'hacked', updated_at = now() + interval '1 day';
  get diagnostics n = row_count;
  assert n = 0, 'B cannot update A''s workout';
end $$;

-- B cannot attach a child to A's parent (composite FK), nor write rows owned by A.
do $$
begin
  begin
    insert into workout_exercises (id, workout_id, exercise_id, position, updated_at)
      values ('31000000-0000-4000-8000-0000000000bb', '30000000-0000-4000-8000-000000000001',
              '00000000-0000-4000-8000-000000000001', 0, now());
    raise exception 'B attached a child to A''s workout';
  exception when foreign_key_violation then null;
  end;
  begin
    insert into workouts (id, user_id, started_at, updated_at)
      values ('30000000-0000-4000-8000-0000000000bb', '00000000-0000-0000-0000-00000000000a', now(), now());
    raise exception 'B inserted a row owned by A';
  exception when insufficient_privilege then null;
  end;
  begin
    delete from workouts;
    raise exception 'authenticated may not hard-delete';
  exception when insufficient_privilege then null;
  end;
end $$;

-- sync_push as B cannot overwrite A's row with the same id.
do $$
declare
  r jsonb;
begin
  r := sync_push(jsonb_build_object('upserts', jsonb_build_object('workouts', jsonb_build_array(
         jsonb_build_object('id', '30000000-0000-4000-8000-000000000001', 'started_at', now(),
                            'notes', 'hijack', 'updated_at', now() + interval '1 day')))));
  assert jsonb_array_length(r -> 'rejected') = 1, 'hijack upsert is rejected: ' || r::text;
  r := sync_push(jsonb_build_object('deletes', jsonb_build_array(
         jsonb_build_object('table', 'workouts', 'id', '30000000-0000-4000-8000-000000000001'))));
end $$;

-- A owns the row unchanged, and cannot give it away.
select t_as('00000000-0000-0000-0000-00000000000a');
update workouts set user_id = '00000000-0000-0000-0000-00000000000b', notes = 'mine', updated_at = now() + interval '1 hour';
do $$
begin
  assert (select notes from workouts) = 'mine', 'A''s own update applies';
  assert (select deleted_at from workouts) is null, 'B''s delete did not touch A''s row';
  assert (select user_id from workouts) = '00000000-0000-0000-0000-00000000000a', 'user_id is immutable';
end $$;

-- Anonymous callers see nothing and cannot push.
reset role;
select t_as(null);
set role anon;
do $$
begin
  begin
    perform count(*) from workouts;
    raise exception 'anon could read workouts';
  exception when insufficient_privilege then null;
  end;
  begin
    perform sync_push('{}'::jsonb);
    raise exception 'anon could call sync_push';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;
