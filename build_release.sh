#!/bin/bash
set -e

if [ ! -f dart_defines.json ]; then
  echo "Error: dart_defines.json no encontrado"
  exit 1
fi

echo "Building Android AAB..."
fvm flutter build appbundle --dart-define-from-file=dart_defines.json

echo ""
echo "AAB generado en: build/app/outputs/bundle/release/app-release.aab"
