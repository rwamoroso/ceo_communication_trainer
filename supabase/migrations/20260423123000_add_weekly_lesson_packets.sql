create table public.weekly_lesson_packets (
  id uuid primary key default gen_random_uuid(),
  plan_version_id uuid not null references public.training_plan_versions(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  week_number int not null check (week_number between 1 and 10),
  weekly_objective text not null default '',
  development_summary text not null default '',
  packet_payload jsonb not null default '{}'::jsonb,
  raw_import_text text not null default '',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique(plan_version_id, week_number)
);

create index idx_weekly_lesson_packets_plan_week
  on public.weekly_lesson_packets (plan_version_id, week_number);

create index idx_weekly_lesson_packets_user_week
  on public.weekly_lesson_packets (user_id, week_number);

drop trigger if exists set_weekly_lesson_packets_updated_at on public.weekly_lesson_packets;
create trigger set_weekly_lesson_packets_updated_at
before update on public.weekly_lesson_packets
for each row execute function public.set_updated_at();

alter table public.weekly_lesson_packets enable row level security;

create policy "own_weekly_lesson_packets"
on public.weekly_lesson_packets for all
using (auth.uid() = user_id or public.is_admin())
with check (auth.uid() = user_id or public.is_admin());
