#!/bin/bash
set -e

if [ ! -f dart_defines.json ]; then
  echo "Error: dart_defines.json no encontrado"
  exit 1
fi

# Build profile → Sentry environment.
#   ./build_release.sh            → beta   (closed testing)  → SENTRY_ENVIRONMENT=staging
#   ./build_release.sh production → prod   (public release)  → environment auto = production
# Default is "beta" so a closed-testing build is never accidentally tagged as
# production in Sentry. Pass "production" explicitly for the public release.
PROFILE="${1:-beta}"
case "$PROFILE" in
  beta)
    SENTRY_ENV_DEFINE="--dart-define=SENTRY_ENVIRONMENT=staging"
    ;;
  production|prod)
    SENTRY_ENV_DEFINE=""  # no override → AppConfig derives "production" from release build mode
    ;;
  *)
    echo "Error: perfil desconocido '$PROFILE' (usa 'beta' o 'production')"
    exit 1
    ;;
esac
echo "Build profile: $PROFILE"

# Load SENTRY_AUTH_TOKEN, SENTRY_ORG, SENTRY_PROJECT from .env.sentry (not committed)
if [ -f .env.sentry ]; then
  set -a; source .env.sentry; set +a
fi

# Derive the app version (e.g. "1.0.4+37") so Dart obfuscation symbols can be
# archived per-version. Without the matching symbols you cannot de-obfuscate a
# crash from that exact build.
APP_VERSION="$(grep '^version:' pubspec.yaml | awk '{print $2}')"
SYMBOLS_DIR="build/symbols/$APP_VERSION"
echo "App version: $APP_VERSION"
echo "Dart symbols dir: $SYMBOLS_DIR"

echo "Building Android AAB (obfuscated)..."
fvm flutter build appbundle $SENTRY_ENV_DEFINE \
  --dart-define-from-file=dart_defines.json \
  --obfuscate \
  --split-debug-info="$SYMBOLS_DIR"

# Upload debug symbols to Sentry for readable stack traces.
# Three kinds of symbols matter:
#   1. Native NDK libs (.so)        → merged_native_libs/
#   2. R8/ProGuard mapping (Kotlin) → mapping/release/
#   3. Dart obfuscation symbols     → $SYMBOLS_DIR  (only exist when --obfuscate is used)
if command -v sentry-cli >/dev/null 2>&1 && [ -n "$SENTRY_AUTH_TOKEN" ]; then
  echo "Uploading debug symbols to Sentry..."
  sentry-cli debug-files upload \
    --org "$SENTRY_ORG" \
    --project "$SENTRY_PROJECT" \
    build/app/intermediates/merged_native_libs/release/ \
    build/app/outputs/mapping/release/ \
    "$SYMBOLS_DIR"
  echo "Symbols uploaded."
else
  echo "sentry-cli not found or SENTRY_AUTH_TOKEN not set — skipping symbol upload."
  echo "To enable: brew install getsentry/tools/sentry-cli and create .env.sentry"
  echo "IMPORTANT: keep $SYMBOLS_DIR archived — required to de-obfuscate crashes from this build."
fi

echo ""
echo "AAB generado en: build/app/outputs/bundle/release/app-release.aab"
