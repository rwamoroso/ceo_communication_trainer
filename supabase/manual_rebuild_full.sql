-- Combined rebuild script generated from repo migrations.
-- Source:
--   1) supabase/migrations/20260419190000_initial_schema.sql
--   2) supabase/migrations/20260420101500_seed_prompts.sql
--   3) supabase/migrations/20260428135923_add_daily_reminder_time.sql
-- Run this in Supabase SQL Editor in order from top to bottom.

-- Begin: 20260419190000_initial_schema.sql
create extension if not exists pgcrypto;

create type public.communication_level as enum (
  'reactive',
  'understandable',
  'structured',
  'manager_ready',
  'director_ready',
  'executive_ready',
  'ceo_level'
);

create type public.prompt_category as enum (
  'bluf_structured_thinking',
  'direct_answer_discipline',
  'brevity_compression',
  'executive_presence',
  'strategic_framing',
  'pressure_response',
  'listening_summarization'
);

create type public.recalibration_state as enum (
  'accelerating',
  'stable',
  'plateau',
  'regressing'
);

create type public.session_status as enum ('in_progress', 'completed');
create type public.plan_item_status as enum ('scheduled', 'completed', 'missed', 'skipped');
create type public.response_mode as enum ('typed', 'audio');
create type public.session_origin as enum ('baseline', 'daily_plan');
create type public.user_role as enum ('admin', 'coach', 'learner');

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.user_roles
    where user_id = auth.uid()
      and role = 'admin'
  );
$$;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  role_title text not null default '',
  seniority_band text not null default '',
  industry text not null default '',
  timezone text not null default 'UTC',
  weekly_goal_count int not null default 5,
  communication_contexts jsonb not null default '[]'::jsonb,
  goals jsonb not null default '[]'::jsonb,
  microphone_consent boolean not null default false,
  preferred_response_mode public.response_mode not null default 'typed',
  daily_reminder_time text not null default '',
  onboarding_completed_at timestamptz,
  baseline_completed_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.communication_baselines (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  completed_at timestamptz not null default timezone('utc', now()),
  overall_score numeric(5,2) not null,
  assigned_level public.communication_level not null,
  readiness_score numeric(5,4) not null,
  strength_pillars jsonb not null default '[]'::jsonb,
  weak_pillars jsonb not null default '[]'::jsonb,
  behavior_snapshot jsonb not null default '{}'::jsonb,
  summary_text text not null default '',
  created_at timestamptz not null default timezone('utc', now())
);

create table public.prompts (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  category public.prompt_category not null,
  difficulty_tier int not null check (difficulty_tier between 1 and 7),
  scenario_context text not null,
  prompt_text text not null,
  target_duration_sec int not null,
  target_word_range_min int not null,
  target_word_range_max int not null,
  pillar_weights jsonb not null default '{}'::jsonb,
  behavior_targets jsonb not null default '{}'::jsonb,
  rubric_version text not null default 'v1',
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.training_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  start_date date not null,
  target_end_date date not null,
  status text not null default 'active',
  current_version_id uuid,
  created_from_baseline_id uuid references public.communication_baselines(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.training_plan_versions (
  id uuid primary key default gen_random_uuid(),
  training_plan_id uuid not null references public.training_plans(id) on delete cascade,
  version_number int not null,
  source text not null,
  generated_at timestamptz not null default timezone('utc', now()),
  week_start_number int not null default 1,
  week_end_number int not null default 10,
  classification_context public.recalibration_state,
  rationale_text text not null default '',
  plan_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  unique(training_plan_id, version_number)
);

alter table public.training_plans
  add constraint training_plans_current_version_fkey
  foreign key (current_version_id)
  references public.training_plan_versions(id)
  on delete set null;

create table public.plan_items (
  id uuid primary key default gen_random_uuid(),
  plan_version_id uuid not null references public.training_plan_versions(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  week_number int not null,
  day_number int not null,
  sequence_number int not null,
  scheduled_for date not null,
  drill_type text not null,
  prompt_id uuid not null references public.prompts(id) on delete restrict,
  focus_pillars jsonb not null default '[]'::jsonb,
  difficulty_tier int not null,
  target_metrics jsonb not null default '{}'::jsonb,
  status public.plan_item_status not null default 'scheduled',
  unlock_rule jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.training_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  plan_item_id uuid references public.plan_items(id) on delete set null,
  prompt_id uuid not null references public.prompts(id) on delete restrict,
  origin public.session_origin not null,
  status public.session_status not null default 'in_progress',
  started_at timestamptz not null default timezone('utc', now()),
  completed_at timestamptz,
  best_attempt_no int,
  final_score numeric(5,2),
  score_delta numeric(5,2),
  device_mode public.response_mode not null default 'typed',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.session_attempts (
  id uuid primary key default gen_random_uuid(),
  training_session_id uuid not null references public.training_sessions(id) on delete cascade,
  attempt_no int not null check (attempt_no between 1 and 2),
  audio_path text,
  duration_ms int not null,
  transcript_text text not null default '',
  word_count int not null default 0,
  word_timings jsonb not null default '[]'::jsonb,
  response_mode public.response_mode not null default 'typed',
  submitted_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),
  unique(training_session_id, attempt_no)
);

create table public.session_scores (
  id uuid primary key default gen_random_uuid(),
  session_attempt_id uuid not null unique references public.session_attempts(id) on delete cascade,
  overall_score numeric(5,2) not null,
  clarity_score numeric(5,2) not null,
  structure_score numeric(5,2) not null,
  brevity_score numeric(5,2) not null,
  presence_score numeric(5,2) not null,
  strategic_framing_score numeric(5,2),
  pressure_response_score numeric(5,2),
  behavior_metrics jsonb not null default '{}'::jsonb,
  scoring_version text not null default 'v1',
  created_at timestamptz not null default timezone('utc', now())
);

create table public.session_feedback (
  id uuid primary key default gen_random_uuid(),
  session_attempt_id uuid not null unique references public.session_attempts(id) on delete cascade,
  biggest_issue text not null,
  secondary_issue text not null default '',
  what_worked text not null default '',
  top_coaching_points jsonb not null default '[]'::jsonb,
  improved_example_answer text not null default '',
  next_attempt_target text not null default '',
  feedback_version text not null default 'v1',
  created_at timestamptz not null default timezone('utc', now())
);

create table public.user_progress (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  current_level public.communication_level not null default 'reactive',
  overall_score_ema numeric(5,2) not null default 0,
  readiness_score numeric(5,4) not null default 0,
  current_streak int not null default 0,
  total_xp int not null default 0,
  weekly_completion_rate numeric(5,4) not null default 0,
  coaching_adoption_rate numeric(5,4) not null default 0,
  difficulty_tolerance numeric(5,4) not null default 0,
  latest_recalibration_state public.recalibration_state not null default 'stable',
  last_session_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.pillar_progress_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  pillar text not null,
  score numeric(5,2) not null,
  source_type text not null,
  source_id uuid,
  recorded_on date not null,
  week_number int not null,
  created_at timestamptz not null default timezone('utc', now())
);

create table public.weekly_recalibrations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  training_plan_id uuid not null references public.training_plans(id) on delete cascade,
  from_version_id uuid references public.training_plan_versions(id) on delete set null,
  to_version_id uuid references public.training_plan_versions(id) on delete set null,
  week_number int not null,
  classification public.recalibration_state not null,
  signal_snapshot jsonb not null default '{}'::jsonb,
  rule_hits jsonb not null default '[]'::jsonb,
  changes_summary text not null default '',
  created_at timestamptz not null default timezone('utc', now())
);

create table public.user_roles (
  user_id uuid not null references public.profiles(id) on delete cascade,
  role public.user_role not null,
  granted_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, role)
);

create table public.coach_assignments (
  id uuid primary key default gen_random_uuid(),
  coach_user_id uuid not null references public.profiles(id) on delete cascade,
  learner_user_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'active',
  created_at timestamptz not null default timezone('utc', now()),
  unique(coach_user_id, learner_user_id)
);

create table public.ai_generation_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  function_name text not null,
  request_schema_version text not null,
  response_valid boolean not null default false,
  latency_ms int,
  error_code text,
  created_at timestamptz not null default timezone('utc', now())
);

create index idx_communication_baselines_user_completed
  on public.communication_baselines (user_id, completed_at desc);
create index idx_plan_items_user_schedule
  on public.plan_items (user_id, scheduled_for);
create index idx_training_sessions_user_created
  on public.training_sessions (user_id, created_at desc);
create index idx_pillar_history_user_pillar_date
  on public.pillar_progress_history (user_id, pillar, recorded_on desc);
create index idx_plan_versions_plan_version
  on public.training_plan_versions (training_plan_id, version_number desc);
create index idx_weekly_recalibrations_user_created
  on public.weekly_recalibrations (user_id, created_at desc);
create index idx_prompts_pillar_weights on public.prompts using gin (pillar_weights);
create index idx_prompts_behavior_targets on public.prompts using gin (behavior_targets);
create index idx_weekly_recalibrations_rule_hits on public.weekly_recalibrations using gin (rule_hits);

create trigger set_profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create trigger set_training_plans_updated_at
before update on public.training_plans
for each row execute function public.set_updated_at();

create trigger set_plan_items_updated_at
before update on public.plan_items
for each row execute function public.set_updated_at();

create trigger set_training_sessions_updated_at
before update on public.training_sessions
for each row execute function public.set_updated_at();

create trigger set_user_progress_updated_at
before update on public.user_progress
for each row execute function public.set_updated_at();

create trigger set_prompts_updated_at
before update on public.prompts
for each row execute function public.set_updated_at();

alter table public.profiles enable row level security;
alter table public.communication_baselines enable row level security;
alter table public.prompts enable row level security;
alter table public.training_plans enable row level security;
alter table public.training_plan_versions enable row level security;
alter table public.plan_items enable row level security;
alter table public.training_sessions enable row level security;
alter table public.session_attempts enable row level security;
alter table public.session_scores enable row level security;
alter table public.session_feedback enable row level security;
alter table public.user_progress enable row level security;
alter table public.pillar_progress_history enable row level security;
alter table public.weekly_recalibrations enable row level security;
alter table public.user_roles enable row level security;
alter table public.coach_assignments enable row level security;
alter table public.ai_generation_logs enable row level security;

create policy "profiles_select_own"
on public.profiles for select
using (auth.uid() = id or public.is_admin());

create policy "profiles_update_own"
on public.profiles for update
using (auth.uid() = id or public.is_admin())
with check (auth.uid() = id or public.is_admin());

create policy "profiles_insert_self"
on public.profiles for insert
with check (auth.uid() = id or public.is_admin());

create policy "prompts_select_active"
on public.prompts for select
using (auth.role() = 'authenticated' and is_active = true or public.is_admin());

create policy "prompts_admin_manage"
on public.prompts for all
using (public.is_admin())
with check (public.is_admin());

create policy "own_baselines"
on public.communication_baselines for all
using (auth.uid() = user_id or public.is_admin())
with check (auth.uid() = user_id or public.is_admin());

create policy "own_training_plans"
on public.training_plans for all
using (auth.uid() = user_id or public.is_admin())
with check (auth.uid() = user_id or public.is_admin());

create policy "own_training_plan_versions"
on public.training_plan_versions for select
using (
  exists (
    select 1
    from public.training_plans tp
    where tp.id = training_plan_id
      and (tp.user_id = auth.uid() or public.is_admin())
  )
);

create policy "own_plan_items"
on public.plan_items for all
using (auth.uid() = user_id or public.is_admin())
with check (auth.uid() = user_id or public.is_admin());

create policy "own_training_sessions"
on public.training_sessions for all
using (auth.uid() = user_id or public.is_admin())
with check (auth.uid() = user_id or public.is_admin());

create policy "own_session_attempts"
on public.session_attempts for select
using (
  exists (
    select 1
    from public.training_sessions ts
    where ts.id = training_session_id
      and (ts.user_id = auth.uid() or public.is_admin())
  )
);

create policy "own_session_attempts_insert"
on public.session_attempts for insert
with check (
  exists (
    select 1
    from public.training_sessions ts
    where ts.id = training_session_id
      and (ts.user_id = auth.uid() or public.is_admin())
  )
);

create policy "own_session_scores"
on public.session_scores for select
using (
  exists (
    select 1
    from public.session_attempts sa
    join public.training_sessions ts on ts.id = sa.training_session_id
    where sa.id = session_attempt_id
      and (ts.user_id = auth.uid() or public.is_admin())
  )
);

create policy "service_insert_session_scores"
on public.session_scores for insert
with check (true);

create policy "own_session_feedback"
on public.session_feedback for select
using (
  exists (
    select 1
    from public.session_attempts sa
    join public.training_sessions ts on ts.id = sa.training_session_id
    where sa.id = session_attempt_id
      and (ts.user_id = auth.uid() or public.is_admin())
  )
);

create policy "service_insert_session_feedback"
on public.session_feedback for insert
with check (true);

create policy "own_user_progress"
on public.user_progress for all
using (auth.uid() = user_id or public.is_admin())
with check (auth.uid() = user_id or public.is_admin());

create policy "own_pillar_history"
on public.pillar_progress_history for all
using (auth.uid() = user_id or public.is_admin())
with check (auth.uid() = user_id or public.is_admin());

create policy "own_weekly_recalibrations"
on public.weekly_recalibrations for all
using (auth.uid() = user_id or public.is_admin())
with check (auth.uid() = user_id or public.is_admin());

create policy "admin_user_roles"
on public.user_roles for all
using (public.is_admin())
with check (public.is_admin());

create policy "coach_assignments_read"
on public.coach_assignments for select
using (coach_user_id = auth.uid() or learner_user_id = auth.uid() or public.is_admin());

create policy "admin_manage_coach_assignments"
on public.coach_assignments for all
using (public.is_admin())
with check (public.is_admin());

create policy "admin_ai_logs"
on public.ai_generation_logs for select
using (public.is_admin());

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'name', ''))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

insert into storage.buckets (id, name, public)
values ('audio_recordings', 'audio_recordings', false)
on conflict (id) do nothing;

create policy "audio_recordings_select_own"
on storage.objects for select
using (
  bucket_id = 'audio_recordings'
  and auth.uid()::text = (storage.foldername(name))[1]
);

create policy "audio_recordings_insert_own"
on storage.objects for insert
with check (
  bucket_id = 'audio_recordings'
  and auth.uid()::text = (storage.foldername(name))[1]
);

create or replace function public.get_dashboard_snapshot(p_user_id uuid default auth.uid())
returns jsonb
language sql
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'profile', to_jsonb(p.*),
    'progress', to_jsonb(up.*),
    'today_items', coalesce((
      select jsonb_agg(pi order by pi.scheduled_for, pi.sequence_number)
      from public.plan_items pi
      join public.training_plans tp on tp.current_version_id = pi.plan_version_id
      where pi.user_id = p_user_id
        and pi.scheduled_for = current_date
    ), '[]'::jsonb),
    'latest_recalibration', (
      select to_jsonb(wr.*)
      from public.weekly_recalibrations wr
      where wr.user_id = p_user_id
      order by wr.created_at desc
      limit 1
    )
  )
  from public.profiles p
  left join public.user_progress up on up.user_id = p.id
  where p.id = p_user_id;
$$;

create or replace function public.start_training_session(p_plan_item_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_session_id uuid;
  v_prompt_id uuid;
begin
  select prompt_id into v_prompt_id
  from public.plan_items
  where id = p_plan_item_id
    and user_id = auth.uid();

  if v_prompt_id is null then
    raise exception 'Plan item not found for current user';
  end if;

  insert into public.training_sessions (
    user_id,
    plan_item_id,
    prompt_id,
    origin,
    device_mode
  ) values (
    auth.uid(),
    p_plan_item_id,
    v_prompt_id,
    'daily_plan',
    'typed'
  )
  returning id into v_session_id;

  return v_session_id;
end;
$$;

create or replace function public.record_session_attempt(
  p_session_id uuid,
  p_attempt_no int,
  p_audio_path text,
  p_duration_ms int,
  p_transcript text,
  p_word_timings jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_attempt_id uuid;
begin
  if not exists (
    select 1
    from public.training_sessions
    where id = p_session_id
      and user_id = auth.uid()
  ) then
    raise exception 'Training session not found for current user';
  end if;

  insert into public.session_attempts (
    training_session_id,
    attempt_no,
    audio_path,
    duration_ms,
    transcript_text,
    word_count,
    word_timings
  )
  values (
    p_session_id,
    p_attempt_no,
    p_audio_path,
    p_duration_ms,
    p_transcript,
    array_length(regexp_split_to_array(trim(coalesce(p_transcript, '')), '\s+'), 1),
    coalesce(p_word_timings, '[]'::jsonb)
  )
  returning id into v_attempt_id;

  return v_attempt_id;
end;
$$;

create or replace function public.refresh_user_progress(p_user_id uuid default auth.uid())
returns public.user_progress
language plpgsql
security definer
set search_path = public
as $$
declare
  v_progress public.user_progress;
  v_last_session timestamptz;
begin
  select max(completed_at) into v_last_session
  from public.training_sessions
  where user_id = p_user_id
    and status = 'completed';

  insert into public.user_progress (user_id, last_session_at)
  values (p_user_id, v_last_session)
  on conflict (user_id) do update
    set last_session_at = excluded.last_session_at;

  select * into v_progress
  from public.user_progress
  where user_id = p_user_id;

  return v_progress;
end;
$$;

create or replace function public.publish_training_plan_version(
  p_user_id uuid,
  p_source text,
  p_payload jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_plan_id uuid;
  v_version_id uuid;
  v_next_version int;
begin
  select id into v_plan_id
  from public.training_plans
  where user_id = p_user_id
  order by created_at desc
  limit 1;

  if v_plan_id is null then
    raise exception 'Training plan not found for user %', p_user_id;
  end if;

  select coalesce(max(version_number), 0) + 1 into v_next_version
  from public.training_plan_versions
  where training_plan_id = v_plan_id;

  insert into public.training_plan_versions (
    training_plan_id,
    version_number,
    source,
    classification_context,
    rationale_text,
    plan_payload
  )
  values (
    v_plan_id,
    v_next_version,
    p_source,
    null,
    coalesce(p_payload ->> 'summary', ''),
    p_payload
  )
  returning id into v_version_id;

  update public.training_plans
  set current_version_id = v_version_id
  where id = v_plan_id;

  return v_version_id;
end;
$$;

create or replace function public.mark_missed_plan_items()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
begin
  update public.plan_items
  set status = 'missed'
  where status = 'scheduled'
    and scheduled_for < current_date;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- Begin: 20260420101500_seed_prompts.sql
insert into public.prompts (
  slug,
  title,
  category,
  difficulty_tier,
  scenario_context,
  prompt_text,
  target_duration_sec,
  target_word_range_min,
  target_word_range_max,
  pillar_weights,
  behavior_targets
)
values
  (
    'baseline-bluf',
    'Status update with BLUF',
    'bluf_structured_thinking',
    1,
    'Your CEO asks for a quick update on a delayed launch.',
    'Give a 45-second update with the answer first, then the three most important points, then the ask.',
    45,
    70,
    105,
    jsonb_build_object('clarity', 0.4, 'structure', 0.4, 'brevity', 0.2),
    jsonb_build_object('direct_answer_rate', 0.8, 'bluf_usage_rate', 0.8)
  ),
  (
    'baseline-direct',
    'Direct answer discipline',
    'direct_answer_discipline',
    1,
    'A VP asks whether the team should pause a feature launch.',
    'Answer yes or no immediately, give your recommendation, and explain only the most important reasoning.',
    35,
    45,
    80,
    jsonb_build_object('clarity', 0.5, 'brevity', 0.3, 'structure', 0.2),
    jsonb_build_object('direct_answer_rate', 0.9, 'response_length_words', 70)
  ),
  (
    'baseline-brevity',
    'Compression under constraint',
    'brevity_compression',
    1,
    'You have 30 seconds at the end of a leadership meeting.',
    'Summarize the update in under 30 seconds without losing the key recommendation.',
    30,
    35,
    55,
    jsonb_build_object('brevity', 0.5, 'clarity', 0.3, 'structure', 0.2),
    jsonb_build_object('response_length_words', 50, 'bluf_usage_rate', 0.7)
  ),
  (
    'baseline-presence',
    'Executive presence',
    'executive_presence',
    1,
    'A senior leader pushes back on your proposal in a meeting.',
    'Respond calmly, keep ownership, and restate the recommendation with confident economy.',
    45,
    55,
    90,
    jsonb_build_object('presence', 0.45, 'clarity', 0.3, 'brevity', 0.25),
    jsonb_build_object('filler_words_per_minute', 4, 'direct_answer_rate', 0.75)
  ),
  (
    'baseline-pressure',
    'Pressure response',
    'pressure_response',
    2,
    'A production outage affects a top-tier customer.',
    'Deliver the immediate response plan, risk framing, and next update cadence.',
    50,
    65,
    100,
    jsonb_build_object('pressure_response', 0.45, 'structure', 0.3, 'clarity', 0.25),
    jsonb_build_object('direct_answer_rate', 0.8, 'clean_three_point_structure_rate', 0.7)
  ),
  (
    'baseline-strategy',
    'Strategic framing',
    'strategic_framing',
    2,
    'The company must choose between two expansion bets.',
    'Recommend one option, explain the tradeoff, and tie it to business impact.',
    60,
    80,
    120,
    jsonb_build_object('strategic_framing', 0.45, 'clarity', 0.25, 'structure', 0.3),
    jsonb_build_object('bluf_usage_rate', 0.8, 'direct_answer_rate', 0.8)
  ),
  (
    'baseline-summary',
    'Listening and summarization',
    'listening_summarization',
    1,
    'A customer call ends with multiple asks and one hidden risk.',
    'Summarize the call in a crisp executive readout with decisions, risks, and next steps.',
    50,
    65,
    95,
    jsonb_build_object('clarity', 0.4, 'structure', 0.4, 'brevity', 0.2),
    jsonb_build_object('clean_three_point_structure_rate', 0.8, 'direct_answer_rate', 0.75)
  ),
  (
    'plan-1',
    'Recommendation with three reasons',
    'direct_answer_discipline',
    1,
    'A leader asks whether to prioritize speed or polish.',
    'Give the recommendation immediately and support it with three short reasons.',
    40,
    55,
    85,
    jsonb_build_object('clarity', 0.45, 'structure', 0.3, 'brevity', 0.25),
    jsonb_build_object('direct_answer_rate', 0.85)
  ),
  (
    'plan-2',
    'Condense the update',
    'brevity_compression',
    1,
    'You get one minute in a staff meeting.',
    'Compress the update into headline, risk, and ask.',
    30,
    35,
    55,
    jsonb_build_object('brevity', 0.45, 'clarity', 0.35, 'structure', 0.2),
    jsonb_build_object('response_length_words', 50)
  ),
  (
    'plan-3',
    'Executive pushback',
    'executive_presence',
    2,
    'An executive challenges your numbers in front of the room.',
    'Respond with calm ownership, keep the answer short, and offer the next step.',
    45,
    55,
    85,
    jsonb_build_object('presence', 0.45, 'clarity', 0.3, 'structure', 0.25),
    jsonb_build_object('filler_words_per_minute', 4)
  ),
  (
    'plan-4',
    'Incident escalation',
    'pressure_response',
    2,
    'A vendor failure may impact revenue this quarter.',
    'Give the escalation summary, immediate action, and executive ask.',
    50,
    65,
    100,
    jsonb_build_object('pressure_response', 0.45, 'structure', 0.3, 'clarity', 0.25),
    jsonb_build_object('direct_answer_rate', 0.8)
  ),
  (
    'plan-5',
    'Strategic recommendation memo',
    'strategic_framing',
    3,
    'Leadership is split between growth and margin.',
    'Recommend one path, name the tradeoff, and tie it to business impact.',
    60,
    85,
    120,
    jsonb_build_object('strategic_framing', 0.5, 'clarity', 0.2, 'structure', 0.3),
    jsonb_build_object('bluf_usage_rate', 0.8)
  ),
  (
    'plan-6',
    'Meeting summary for a VP',
    'listening_summarization',
    2,
    'A long cross-functional meeting ended with unclear ownership.',
    'Summarize what matters, what changed, and who owns the next move.',
    45,
    55,
    90,
    jsonb_build_object('clarity', 0.35, 'structure', 0.45, 'brevity', 0.2),
    jsonb_build_object('clean_three_point_structure_rate', 0.8)
  ),
  (
    'plan-7',
    'BLUF with escalation',
    'bluf_structured_thinking',
    2,
    'A key dependency slipped and leadership needs the headline fast.',
    'Deliver a bottom-line-up-front update with the problem, impact, and ask.',
    40,
    55,
    85,
    jsonb_build_object('clarity', 0.4, 'structure', 0.4, 'brevity', 0.2),
    jsonb_build_object('bluf_usage_rate', 0.85)
  ),
  (
    'plan-8',
    'Answer under ambiguity',
    'direct_answer_discipline',
    3,
    'The data is incomplete but leadership still wants a recommendation.',
    'Give your recommendation, note the uncertainty, and propose the safest next move.',
    50,
    60,
    95,
    jsonb_build_object('clarity', 0.45, 'structure', 0.25, 'pressure_response', 0.3),
    jsonb_build_object('direct_answer_rate', 0.85)
  )
on conflict (slug) do update
set
  title = excluded.title,
  category = excluded.category,
  difficulty_tier = excluded.difficulty_tier,
  scenario_context = excluded.scenario_context,
  prompt_text = excluded.prompt_text,
  target_duration_sec = excluded.target_duration_sec,
  target_word_range_min = excluded.target_word_range_min,
  target_word_range_max = excluded.target_word_range_max,
  pillar_weights = excluded.pillar_weights,
  behavior_targets = excluded.behavior_targets,
  is_active = true;
