alter table public.profiles
  add column if not exists daily_reminder_time text not null default '';
