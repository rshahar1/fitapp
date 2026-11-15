-- Hardening (feature 013): size and range limits so one account cannot fill the database with oversized rows.
-- Every limit sits well above what the app can produce (activity notes 200, names 40, distance 1,000 km,
-- duration 24 h, rest 600 s), so real data is never rejected. sync_push rejects violating rows one by one.

alter table public.custom_exercises
  add constraint custom_exercises_muscle_group_len check (length(muscle_group) <= 40),
  add constraint custom_exercises_increment_max check (default_increment <= 100);

alter table public.exercise_state
  add constraint exercise_state_ranges check (
    base_weight <= 2000 and increment <= 100 and target_reps <= 1000 and target_sets <= 100
    and (rest_seconds is null or rest_seconds <= 3600));

alter table public.template_exercises
  add constraint template_exercises_ranges check (
    position <= 1000
    and (base_weight is null or base_weight <= 2000)
    and (increment is null or increment <= 100)
    and (target_reps is null or target_reps <= 1000)
    and (target_sets is null or target_sets <= 100)
    and (rest_seconds is null or rest_seconds <= 3600));

alter table public.workouts
  add constraint workouts_name_len check (length(name) <= 80),
  add constraint workouts_notes_len check (length(notes) <= 10000);

alter table public.workout_exercises
  add constraint workout_exercises_notes_len check (length(notes) <= 10000),
  add constraint workout_exercises_position_max check (position <= 1000);

alter table public.sets
  add constraint sets_ranges check (set_no <= 1000 and weight <= 2000 and reps <= 10000);

alter table public.activities
  add constraint activities_type_id_len check (length(type_id) <= 40),
  add constraint activities_notes_len check (length(notes) <= 1000),
  add constraint activities_route_len check (length(route) <= 1000000),
  add constraint activities_splits_len check (length(splits) <= 100000),
  add constraint activities_ranges check (
    (duration_minutes is null or duration_minutes <= 10080)
    and (distance_meters is null or distance_meters <= 10000000)
    and (moving_seconds is null or moving_seconds <= 604800)
    and (elevation_gain_meters is null or abs(elevation_gain_meters) <= 100000));

alter table public.user_settings
  add constraint user_settings_size check (pg_column_size(data) <= 2048);
