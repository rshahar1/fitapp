-- Deleting an account removes all of its synced rows (FR-007), despite forced RLS.

set role authenticated;
select t_as('00000000-0000-0000-0000-00000000000a');
insert into workouts (id, started_at, updated_at)
  values ('30000000-0000-4000-8000-000000000001', now(), now());
insert into workout_exercises (id, workout_id, exercise_id, position, updated_at)
  values ('31000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000001',
          '00000000-0000-4000-8000-000000000001', 0, now());
insert into sets (id, workout_exercise_id, set_no, weight, reps, is_overload, completed_at, updated_at)
  values ('32000000-0000-4000-8000-000000000001', '31000000-0000-4000-8000-000000000001',
          1, 60, 8, false, now(), now());
insert into user_settings (data, updated_at) values ('{}', now());
select t_as('00000000-0000-0000-0000-00000000000b');
insert into workouts (id, started_at, updated_at)
  values ('30000000-0000-4000-8000-0000000000bb', now(), now());
reset role;

delete from auth.users where id = '00000000-0000-0000-0000-00000000000a';

do $$
begin
  assert (select count(*) from workouts) = 1, 'only B''s workout remains';
  assert (select count(*) from workout_exercises) = 0, 'A''s workout exercises deleted';
  assert (select count(*) from sets) = 0, 'A''s sets deleted';
  assert (select count(*) from user_settings) = 0, 'A''s settings deleted';
end $$;
