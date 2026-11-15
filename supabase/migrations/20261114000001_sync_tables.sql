-- Feature 013: cloud backup and sync. Tables mirror the local drift schema (specs/013-cloud-sync/data-model.md §2).
-- Common bookkeeping on every table:
--   user_id            owner, defaults to the caller, immutable (trigger), cascades on account deletion
--   updated_at         client clock, last-writer-wins
--   deleted_at         tombstone; rows are never hard-deleted by sync
--   server_updated_at  set by trigger, the pull cursor

create table public.custom_exercises (
  id                uuid primary key,
  user_id           uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name              text not null check (length(name) between 1 and 80),
  muscle_group      text,
  is_per_hand       boolean not null,
  default_increment double precision not null check (default_increment >= 0),
  archived_at       timestamptz,
  updated_at        timestamptz not null,
  deleted_at        timestamptz,
  server_updated_at timestamptz not null default clock_timestamp()
);

-- Per-user state of built-in exercises (the library itself ships with the app).
create table public.exercise_overrides (
  user_id           uuid not null default auth.uid() references auth.users (id) on delete cascade,
  exercise_id       uuid not null,
  archived_at       timestamptz,
  updated_at        timestamptz not null,
  deleted_at        timestamptz,
  server_updated_at timestamptz not null default clock_timestamp(),
  primary key (user_id, exercise_id)
);

create table public.exercise_state (
  user_id           uuid not null default auth.uid() references auth.users (id) on delete cascade,
  exercise_id       uuid not null,
  base_weight       double precision not null check (base_weight >= 0),
  target_reps       integer not null check (target_reps > 0),
  target_sets       integer not null check (target_sets > 0),
  increment         double precision not null check (increment >= 0),
  rest_seconds      integer check (rest_seconds >= 0),
  updated_at        timestamptz not null,
  deleted_at        timestamptz,
  server_updated_at timestamptz not null default clock_timestamp(),
  primary key (user_id, exercise_id)
);

create table public.templates (
  id                uuid primary key,
  user_id           uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name              text not null check (length(name) between 1 and 80),
  created_at        timestamptz not null,
  last_used_at      timestamptz,
  updated_at        timestamptz not null,
  deleted_at        timestamptz,
  server_updated_at timestamptz not null default clock_timestamp(),
  unique (id, user_id)
);

create table public.template_exercises (
  id                uuid primary key,
  user_id           uuid not null default auth.uid() references auth.users (id) on delete cascade,
  template_id       uuid not null,
  exercise_id       uuid not null,
  position          integer not null check (position >= 0),
  base_weight       double precision check (base_weight >= 0),
  target_reps       integer check (target_reps > 0),
  target_sets       integer check (target_sets > 0),
  increment         double precision check (increment >= 0),
  rest_seconds      integer check (rest_seconds >= 0),
  updated_at        timestamptz not null,
  deleted_at        timestamptz,
  server_updated_at timestamptz not null default clock_timestamp(),
  -- Composite FK: a row can only hang under a parent of the same owner.
  foreign key (template_id, user_id) references public.templates (id, user_id) on delete cascade
);

create table public.workouts (
  id                uuid primary key,
  user_id           uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name              text,
  started_at        timestamptz not null,
  ended_at          timestamptz,
  notes             text,
  updated_at        timestamptz not null,
  deleted_at        timestamptz,
  server_updated_at timestamptz not null default clock_timestamp(),
  unique (id, user_id)
);

create table public.workout_exercises (
  id                   uuid primary key,
  user_id              uuid not null default auth.uid() references auth.users (id) on delete cascade,
  workout_id           uuid not null,
  exercise_id          uuid not null,
  position             integer not null check (position >= 0),
  notes                text,
  template_exercise_id uuid,
  plan_base_weight     double precision,
  plan_target_reps     integer,
  plan_target_sets     integer,
  plan_increment       double precision,
  result_base_weight   double precision,
  updated_at           timestamptz not null,
  deleted_at           timestamptz,
  server_updated_at    timestamptz not null default clock_timestamp(),
  unique (id, user_id),
  foreign key (workout_id, user_id) references public.workouts (id, user_id) on delete cascade
);

create table public.sets (
  id                  uuid primary key,
  user_id             uuid not null default auth.uid() references auth.users (id) on delete cascade,
  workout_exercise_id uuid not null,
  set_no              integer not null check (set_no > 0),
  weight              double precision not null check (weight >= 0),
  reps                integer not null check (reps >= 0),
  is_overload         boolean not null,
  completed_at        timestamptz not null,
  updated_at          timestamptz not null,
  deleted_at          timestamptz,
  server_updated_at   timestamptz not null default clock_timestamp(),
  foreign key (workout_exercise_id, user_id)
    references public.workout_exercises (id, user_id) on delete cascade
);

create table public.activities (
  id                    uuid primary key,
  user_id               uuid not null default auth.uid() references auth.users (id) on delete cascade,
  type_id               text not null,
  started_at            timestamptz not null,
  duration_minutes      integer check (duration_minutes >= 0),
  distance_meters       integer check (distance_meters >= 0),
  notes                 text,
  source                text not null default 'manual' check (source in ('manual', 'gps')),
  moving_seconds        integer check (moving_seconds >= 0),
  elevation_gain_meters integer,
  route                 text,
  splits                text,
  updated_at            timestamptz not null,
  deleted_at            timestamptz,
  server_updated_at     timestamptz not null default clock_timestamp()
);

create table public.user_settings (
  user_id           uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  data              jsonb not null default '{}'::jsonb,
  updated_at        timestamptz not null,
  deleted_at        timestamptz,
  server_updated_at timestamptz not null default clock_timestamp()
);

-- Pull cursor indexes.
create index custom_exercises_pull   on public.custom_exercises   (user_id, server_updated_at);
create index exercise_overrides_pull on public.exercise_overrides (user_id, server_updated_at);
create index exercise_state_pull     on public.exercise_state     (user_id, server_updated_at);
create index templates_pull          on public.templates          (user_id, server_updated_at);
create index template_exercises_pull on public.template_exercises (user_id, server_updated_at);
create index workouts_pull           on public.workouts           (user_id, server_updated_at);
create index workout_exercises_pull  on public.workout_exercises  (user_id, server_updated_at);
create index sets_pull               on public.sets               (user_id, server_updated_at);
create index activities_pull         on public.activities         (user_id, server_updated_at);
create index user_settings_pull      on public.user_settings      (user_id, server_updated_at);

-- FK lookups used by the tombstone triggers.
create index template_exercises_template on public.template_exercises (template_id);
create index workout_exercises_workout   on public.workout_exercises  (workout_id);
create index sets_workout_exercise       on public.sets               (workout_exercise_id);
