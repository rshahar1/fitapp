-- Feature 013: one-call push (contracts/sync-backend.md). SECURITY INVOKER: RLS and triggers apply.

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
    when 'activities'         then array['id','type_id','started_at','duration_minutes','distance_meters','notes','source','moving_seconds','elevation_gain_meters','route','splits','updated_at']
    when 'user_settings'      then array['data','updated_at']
  end
$$;

create or replace function public.sync_conflict_target(t text) returns text
language sql immutable set search_path = public, pg_temp as $$
  select case t
    when 'exercise_overrides' then 'user_id, exercise_id'
    when 'exercise_state'     then 'user_id, exercise_id'
    when 'user_settings'      then 'user_id'
    else 'id'
  end
$$;

create or replace function public.sync_push(payload jsonb) returns jsonb
language plpgsql security invoker set search_path = public, pg_temp as $$
declare
  upsert_order constant text[] := array[
    'custom_exercises', 'exercise_overrides', 'exercise_state', 'templates', 'template_exercises',
    'workouts', 'workout_exercises', 'sets', 'activities', 'user_settings'];
  deletable constant text[] := array[
    'custom_exercises', 'templates', 'template_exercises', 'workouts', 'workout_exercises', 'sets',
    'activities'];
  item jsonb;
  t text;
  cols text[];
  col_list text;
  set_list text;
  applied integer := 0;
  rejected jsonb := '[]'::jsonb;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  -- 1. Deletes become tombstones, in the order given (children first).
  for item in select value from jsonb_array_elements(coalesce(payload -> 'deletes', '[]'::jsonb)) loop
    begin
      t := item ->> 'table';
      if t is null or not (t = any (deletable)) then
        raise exception 'table % cannot be deleted', t using errcode = '22023';
      end if;
      execute format(
        'update public.%I set deleted_at = now(), updated_at = now() '
        'where id = $1 and deleted_at is null', t)
        using (item ->> 'id')::uuid;
      applied := applied + 1;
    exception when others then
      rejected := rejected || jsonb_build_object(
        'table', item ->> 'table', 'id', item ->> 'id', 'error', sqlstate || ': ' || sqlerrm);
    end;
  end loop;

  -- 2. Upserts in FK order; each row isolated so one bad row never blocks the rest.
  foreach t in array upsert_order loop
    cols := public.sync_columns(t);
    col_list := (select string_agg(quote_ident(c), ', ') from unnest(cols) c);
    set_list := (
      select string_agg(format('%1$I = excluded.%1$I', c), ', ')
      from unnest(cols) c
      where c not in ('id', 'exercise_id'));
    for item in select value from jsonb_array_elements(coalesce(payload -> 'upserts' -> t, '[]'::jsonb)) loop
      begin
        execute format(
          'insert into public.%1$I (%2$s) select %2$s from jsonb_populate_record(null::public.%1$I, $1) '
          'on conflict (%3$s) do update set %4$s',
          t, col_list, public.sync_conflict_target(t), set_list)
          using item;
        applied := applied + 1;
      exception when others then
        rejected := rejected || jsonb_build_object(
          'table', t, 'id', coalesce(item ->> 'id', item ->> 'exercise_id'),
          'error', sqlstate || ': ' || sqlerrm);
      end;
    end loop;
  end loop;

  return jsonb_build_object('applied', applied, 'rejected', rejected);
end $$;

revoke execute on function public.sync_push(jsonb) from public, anon;
grant execute on function public.sync_push(jsonb) to authenticated;
