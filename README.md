# CEO Communication Trainer

A Flutter app with Supabase backend that helps users improve executive communication.
Core features:
- 10-week adaptive training plan
- user assessment
- weekly recalibration
- speech/articulation exercises
- progress dashboard
- session history
- AI-generated personalized coaching prompts

## Run modes

Demo mode is the default:

```bash
flutter run
```

Supabase mode uses email link auth plus persisted profile/session/plan data:

```bash
flutter run \
  --dart-define=APP_USE_FAKE_BACKEND=false \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

## Supabase setup

1. Apply the SQL migrations in `supabase/migrations/`.
2. Enable email auth in your Supabase project.
3. Add this redirect URL to the project's allowed redirect URLs:

```text
ceocommunicationtrainer://auth-callback
```

The live app still uses the local deterministic scoring and adaptive-plan engine for now. Supabase is wired up as the real auth and persistence layer, while the edge functions remain scaffolded.
