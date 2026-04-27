#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Build and/or upload an iOS IPA to TestFlight using App Store Connect API keys.

Usage:
  scripts/testflight_upload.sh [options]

Options:
  --build-number N     Override Flutter iOS build number (CFBundleVersion).
                      If omitted for a build, a UTC timestamp is used.
  --ipa PATH           Upload a specific IPA file (implies --skip-build unless --build is passed).
  --skip-build         Skip `flutter build ipa` and upload an existing IPA.
  --build              Force a build even if --ipa is provided.
  --preflight          Validate local tooling + App Store Connect auth config, then exit.
  --validate-only      Run altool validation instead of upload.
  --no-source-env      Do not load scripts/testflight.env automatically.
  -h, --help           Show this help.

Environment (required):
  ASC_API_KEY_ID       App Store Connect API Key ID
  ASC_API_ISSUER_ID    App Store Connect API Issuer ID

Environment (one of these):
  ASC_API_P8_PATH      Full path to AuthKey_<KEYID>.p8 (preferred)
  API_PRIVATE_KEYS_DIR Directory containing AuthKey_<KEYID>.p8
                      (altool also checks ~/.appstoreconnect/private_keys)

Optional:
  FLUTTER_BIN          Path to flutter binary (default: ~/flutter/bin/flutter, then PATH)

Examples:
  scripts/testflight_upload.sh --build-number 5
  scripts/testflight_upload.sh --skip-build
  scripts/testflight_upload.sh --ipa build/ios/ipa/ceo_communication_trainer.ipa
EOF
}

log() {
  printf '[testflight] %s\n' "$*"
}

die() {
  printf '[testflight] ERROR: %s\n' "$*" >&2
  exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source_env=1
skip_build=0
force_build=0
validate_only=0
preflight_only=0
build_number=""
ipa_path=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build-number)
      [[ $# -ge 2 ]] || die "--build-number requires a value"
      build_number="$2"
      shift 2
      ;;
    --ipa)
      [[ $# -ge 2 ]] || die "--ipa requires a path"
      ipa_path="$2"
      shift 2
      ;;
    --skip-build)
      skip_build=1
      shift
      ;;
    --build)
      force_build=1
      shift
      ;;
    --validate-only)
      validate_only=1
      shift
      ;;
    --preflight)
      preflight_only=1
      shift
      ;;
    --no-source-env)
      source_env=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown option: $1"
      ;;
  esac
done

if [[ "${source_env}" -eq 1 ]]; then
  if [[ -f "${REPO_ROOT}/scripts/testflight.env" ]]; then
    # shellcheck disable=SC1091
    source "${REPO_ROOT}/scripts/testflight.env"
  fi
fi

if [[ -n "${ipa_path}" && "${force_build}" -eq 0 ]]; then
  skip_build=1
fi

if [[ -z "${ASC_API_KEY_ID:-}" ]]; then
  die "ASC_API_KEY_ID is not set"
fi
if [[ -z "${ASC_API_ISSUER_ID:-}" ]]; then
  die "ASC_API_ISSUER_ID is not set"
fi

resolve_flutter_bin() {
  if [[ -n "${FLUTTER_BIN:-}" ]]; then
    printf '%s\n' "${FLUTTER_BIN}"
    return 0
  fi
  if [[ -x "${HOME}/flutter/bin/flutter" ]]; then
    printf '%s\n' "${HOME}/flutter/bin/flutter"
    return 0
  fi
  if command -v flutter >/dev/null 2>&1; then
    command -v flutter
    return 0
  fi
  return 1
}

resolve_ipa_path() {
  if [[ -n "${ipa_path}" ]]; then
    [[ -f "${ipa_path}" ]] || die "IPA not found: ${ipa_path}"
    printf '%s\n' "${ipa_path}"
    return 0
  fi
  shopt -s nullglob
  local matches=("${REPO_ROOT}"/build/ios/ipa/*.ipa)
  shopt -u nullglob
  [[ ${#matches[@]} -gt 0 ]] || die "No IPA found in build/ios/ipa. Build first or pass --ipa."
  ls -t "${matches[@]}" | head -n 1
}

require_cmd() {
  local name="$1"
  command -v "${name}" >/dev/null 2>&1 || die "Required command not found: ${name}"
}

verify_preflight() {
  require_cmd xcrun
  xcrun altool --help >/dev/null 2>&1 || die "xcrun altool is not available"

  if [[ "${skip_build}" -eq 0 || "${preflight_only}" -eq 1 ]]; then
    local flutter_bin
    flutter_bin="$(resolve_flutter_bin)" || die "Flutter binary not found. Set FLUTTER_BIN or add flutter to PATH."
    [[ -x "${flutter_bin}" ]] || die "Flutter binary is not executable: ${flutter_bin}"
    log "Flutter OK: ${flutter_bin}"
  fi

  prepare_altool_auth_args
  log "App Store Connect API auth config OK"

  if command -v security >/dev/null 2>&1; then
    if security find-identity -v -p codesigning 2>/dev/null | grep -q "Apple Distribution:"; then
      log "Apple Distribution signing identity found"
    else
      log "WARNING: No Apple Distribution signing identity found in keychain"
    fi
  fi
}

build_ipa() {
  local flutter_bin
  flutter_bin="$(resolve_flutter_bin)" || die "Flutter binary not found. Set FLUTTER_BIN or add flutter to PATH."

  log "Using Flutter: ${flutter_bin}"
  log "Building App Store IPA..."

  local effective_build_number="${build_number}"
  if [[ -z "${effective_build_number}" ]]; then
    effective_build_number="$(date -u +%Y%m%d%H%M%S)"
    log "Auto build number: ${effective_build_number}"
  fi

  local cmd=(
    "${flutter_bin}" "build" "ipa"
    "--release"
    "--export-method" "app-store"
    "--build-number" "${effective_build_number}"
  )

  (
    cd "${REPO_ROOT}"
    "${cmd[@]}"
  )
}

prepare_altool_auth_args() {
  ALTOOL_AUTH_ARGS=(
    "--api-key" "${ASC_API_KEY_ID}"
    "--api-issuer" "${ASC_API_ISSUER_ID}"
  )

  if [[ -n "${ASC_API_P8_PATH:-}" ]]; then
    [[ -f "${ASC_API_P8_PATH}" ]] || die "ASC_API_P8_PATH file not found: ${ASC_API_P8_PATH}"
    ALTOOL_AUTH_ARGS+=("--p8-file-path" "${ASC_API_P8_PATH}")
    return 0
  fi

  if [[ -n "${API_PRIVATE_KEYS_DIR:-}" ]]; then
    local candidate="${API_PRIVATE_KEYS_DIR}/AuthKey_${ASC_API_KEY_ID}.p8"
    [[ -f "${candidate}" ]] || die "Expected key not found: ${candidate}"
    export API_PRIVATE_KEYS_DIR
    return 0
  fi

  local default_candidate="${HOME}/.appstoreconnect/private_keys/AuthKey_${ASC_API_KEY_ID}.p8"
  if [[ -f "${default_candidate}" ]]; then
    return 0
  fi

  die "No API key file configured. Set ASC_API_P8_PATH or API_PRIVATE_KEYS_DIR."
}

main() {
  verify_preflight

  if [[ "${preflight_only}" -eq 1 ]]; then
    log "Preflight checks passed."
    exit 0
  fi

  if [[ "${skip_build}" -eq 0 ]]; then
    build_ipa
  else
    log "Skipping build step."
  fi

  local ipa
  ipa="$(resolve_ipa_path)"
  log "IPA: ${ipa}"

  local mode="upload"
  local altool_cmd=(xcrun altool)
  if [[ "${validate_only}" -eq 1 ]]; then
    mode="validate"
    altool_cmd+=("--validate-app" "-f" "${ipa}")
  else
    altool_cmd+=("--upload-app" "-f" "${ipa}")
  fi
  altool_cmd+=("${ALTOOL_AUTH_ARGS[@]}" "--output-format" "json" "--show-progress")

  log "Starting App Store Connect ${mode} via altool..."
  "${altool_cmd[@]}"

  cat <<'EOF'
[testflight] Upload submitted.
[testflight] Next:
[testflight]   1) Open App Store Connect > TestFlight
[testflight]   2) Wait for processing to finish
[testflight]   3) Assign to internal testers (or submit for external beta review)
EOF
}

main "$@"
