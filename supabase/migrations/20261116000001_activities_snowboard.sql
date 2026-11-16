-- Feature 017: snowboarding metrics of tracked activities (all optional).

alter table public.activities
  add column vertical_drop_meters integer check (vertical_drop_meters >= 0),
  add column run_count integer check (run_count >= 0),
  add column max_speed_mps double precision check (max_speed_mps >= 0),
  add column lift_seconds integer check (lift_seconds >= 0),
  add column rest_seconds integer check (rest_seconds >= 0),
  add column segments text;

alter table public.activities
  add constraint activities_segments_len check (length(segments) <= 300000);

-- Columns a client may send per table (never user_id, deleted_at, server_updated_at).
create or replace function public.sync_columns(t text) returns text[]
language sql immutable set search_path = public, pg_temp as $$
  select case t
    when 'custom_exercises'   then array['id','name','muscle_group','is_per_hand','default_increment','archived_at','updated_at']
    when 'exercise_overrides' then array['exercise_id','archived_at','updated_at']
    when 'exercise_state'     then array['exercise_id','base_weight','target_reps','target_sets','increment','rest_seconds','updated_at']
    when 'templates'          then array['id','name','created_at','last_used_at','updated_at']
    when 'template_exercises' then array['id','template_id','exercise_id','position','base_weight','target_reps','target_sets','increment','rest_seconds','updated_at']
    when 'workouts'           then array['id','name','started_at','ended_at','notes','updated_at']
    when 'workout_exercises'  then array['id','workout_id','exercise_id','position','notes','template_exercise_id','plan_base_weight','plan_target_reps','plan_target_sets','plan_increment','result_base_weight','updated_at']
    when 'sets'               then array['id','workout_exercise_id','set_no','weight','reps','is_overload','completed_at','updated_at']
    when 'activities'         then array['id','type_id','started_at','duration_minutes','distance_meters','notes','source','moving_seconds','elevation_gain_meters','route','splits','vertical_drop_meters','run_count','max_speed_mps','lift_seconds','rest_seconds','segments','updated_at']
    when 'user_settings'      then array['data','updated_at']
  end
$$;
