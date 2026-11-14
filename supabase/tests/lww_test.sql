-- Last-writer-wins on client updated_at (FR-017) and a fresh pull cursor on every accepted write.

set role authenticated;
select t_as('00000000-0000-0000-0000-00000000000a');

insert into exercise_state (exercise_id, base_weight, target_reps, target_sets, increment, updated_at)
  values ('00000000-0000-4000-8000-000000000001', 60, 8, 3, 2.5, '2026-11-14T10:00:00Z');

do $$
declare
  cursor1 timestamptz;
  r jsonb;
begin
  cursor1 := (select server_updated_at from exercise_state);

  -- Older edit (device clock behind) loses.
  r := sync_push(jsonb_build_object('upserts', jsonb_build_object('exercise_state', jsonb_build_array(
         jsonb_build_object('exercise_id', '00000000-0000-4000-8000-000000000001', 'base_weight', 50,
           'target_reps', 8, 'target_sets', 3, 'increment', 2.5, 'updated_at', '2026-11-14T09:00:00Z')))));
  assert (r ->> 'applied')::int = 1 and jsonb_array_length(r -> 'rejected') = 0, r::text;
  assert (select base_weight from exercise_state) = 60, 'older write must not win';
  assert (select server_updated_at from exercise_state) = cursor1, 'skipped write keeps cursor';

  -- Newer edit wins and advances the cursor.
  r := sync_push(jsonb_build_object('upserts', jsonb_build_object('exercise_state', jsonb_build_array(
         jsonb_build_object('exercise_id', '00000000-0000-4000-8000-000000000001', 'base_weight', 62.5,
           'target_reps', 8, 'target_sets', 3, 'increment', 2.5, 'updated_at', '2026-11-14T11:00:00Z')))));
  assert (select base_weight from exercise_state) = 62.5, 'newer write wins';
  assert (select server_updated_at from exercise_state) > cursor1, 'accepted write advances cursor';

  -- Equal timestamps: the later arrival wins (idempotent re-push is harmless).
  r := sync_push(jsonb_build_object('upserts', jsonb_build_object('exercise_state', jsonb_build_array(
         jsonb_build_object('exercise_id', '00000000-0000-4000-8000-000000000001', 'base_weight', 62.5,
           'target_reps', 10, 'target_sets', 3, 'increment', 2.5, 'updated_at', '2026-11-14T11:00:00Z')))));
  assert (select target_reps from exercise_state) = 10, 'equal timestamp applies';
end $$;

-- Same per-user key for B is a separate row (built-in ids are shared across users).
select t_as('00000000-0000-0000-0000-00000000000b');
do $$
declare
  r jsonb;
begin
  r := sync_push(jsonb_build_object('upserts', jsonb_build_object('exercise_state', jsonb_build_array(
         jsonb_build_object('exercise_id', '00000000-0000-4000-8000-000000000001', 'base_weight', 40,
           'target_reps', 8, 'target_sets', 3, 'increment', 2.5, 'updated_at', '2026-11-14T12:00:00Z')))));
  assert jsonb_array_length(r -> 'rejected') = 0, r::text;
  assert (select base_weight from exercise_state) = 40, 'B has its own plan';
end $$;
reset role;
do $$
begin
  assert (select count(*) from exercise_state) = 2, 'one plan per user';
end $$;
