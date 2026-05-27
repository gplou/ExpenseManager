#!/bin/bash
set -e

if [ ! -f dart_defines.json ]; then
  echo "Error: dart_defines.json no encontrado"
  exit 1
fi

# Load SENTRY_AUTH_TOKEN, SENTRY_ORG, SENTRY_PROJECT from .env.sentry (not committed)
if [ -f .env.sentry ]; then
  set -a; source .env.sentry; set +a
fi

echo "Building Android AAB..."
fvm flutter build appbundle --dart-define-from-file=dart_defines.json

# Upload debug symbols to Sentry for readable stack traces
if command -v sentry-cli >/dev/null 2>&1 && [ -n "$SENTRY_AUTH_TOKEN" ]; then
  echo "Uploading debug symbols to Sentry..."
  sentry-cli debug-files upload \
    --org "$SENTRY_ORG" \
    --project "$SENTRY_PROJECT" \
    build/app/intermediates/merged_native_libs/release/ \
    build/app/outputs/mapping/release/
  echo "Symbols uploaded."
else
  echo "sentry-cli not found or SENTRY_AUTH_TOKEN not set — skipping symbol upload."
  echo "To enable: brew install getsentry/tools/sentry-cli and create .env.sentry"
fi

echo ""
echo "AAB generado en: build/app/outputs/bundle/release/app-release.aab"
