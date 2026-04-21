#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

flutter run "$@" \
  --dart-define=APP_USE_FAKE_BACKEND=false \
  --dart-define=SUPABASE_URL=https://cirbtiruwefyhqthbcyc.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_y7kJZxrpoBBmBSesZv1xpQ_OhqcPvpV
