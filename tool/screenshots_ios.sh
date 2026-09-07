#!/bin/bash
# ANDAMIAJE TEMPORAL — genera la tanda de capturas de la App Store.
#
#   bash tool/screenshots_ios.sh [udid]
#
# Por defecto usa un iPhone 17 Pro Max (1320×2868 px = tamaño 6,9" exacto que
# pide App Store Connect). Arranca el simulador, fija la barra de estado en el
# 9:41 canónico, lanza el daemon de captura y conduce la app con
# `integration_test/screenshots_test.dart`.
set -euo pipefail

UDID="${1:-$(xcrun simctl list devices available | awk '/iPhone 17 Pro Max/ {print $NF; exit}' | tr -d '()')}"
BUNDLE="com.gpm.expensemanagerapp"
OUT="screenshots/ios"

echo "▶︎ simulador: $UDID"
xcrun simctl boot "$UDID" 2>/dev/null || true
open -a Simulator
xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || true

# Barra de estado determinista (si no, sale la hora real y la batería del Mac).
xcrun simctl status_bar "$UDID" override \
  --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiMode active --wifiBars 3

# Instalación limpia: si queda la BD de una tanda anterior, la siembra de datos
# de demo se salta (es idempotente) y las cifras no se regeneran.
xcrun simctl uninstall "$UDID" "$BUNDLE" 2>/dev/null || true
rm -f "$OUT"/*.png

run_pass() { # $1 = etiqueta, $2… = dart-defines extra
  local label="$1"; shift
  echo "▶︎ pasada: $label"
  bash tool/screenshots/daemon.sh "$UDID" "$BUNDLE" "$OUT" &
  local daemon=$!
  # shellcheck disable=SC2064
  trap "kill $daemon 2>/dev/null || true" EXIT
  fvm flutter drive \
    --driver=test_driver/integration_test.dart \
    --target=tool/screenshots/screenshots_test.dart \
    --dart-define-from-file=dart_defines.json \
    --dart-define-from-file=dart_defines_e2e.json \
    --dart-define=SCREENSHOT_MODE=true \
    "$@" \
    -d "$UDID"
  kill $daemon 2>/dev/null || true
  trap - EXIT
}

run_pass "tema claro"

# El tema hay que fijarlo en SharedPreferences antes de arrancar la app, así que
# el modo oscuro necesita una segunda ejecución. No se desinstala: reutiliza la
# sesión y los mismos datos sembrados, y las cifras coinciden con las claras.
run_pass "tema oscuro" --dart-define=SHOT_DARK=true

echo "✔︎ capturas en $OUT/"
ls -1 "$OUT"
