#!/bin/bash
# ANDAMIAJE TEMPORAL — lado host de la tanda de capturas de iOS.
#
# Vigila el buzón que el test deja en el contenedor de datos de la app
# (Documents/screenshots). Por cada `<nombre>.request` captura la pantalla del
# simulador con `simctl` y escribe `<nombre>.done` para desbloquear al test.
#
# Uso: screenshot_daemon.sh <udid> <bundle-id> <dir-salida>
set -uo pipefail

UDID="$1"
BUNDLE="$2"
OUT="$3"

mkdir -p "$OUT"

echo "[daemon] esperando a que la app se instale…"
CONTAINER=""
for _ in $(seq 1 300); do
  CONTAINER=$(xcrun simctl get_app_container "$UDID" "$BUNDLE" data 2>/dev/null || true)
  [ -n "$CONTAINER" ] && [ -d "$CONTAINER/Documents" ] && break
  sleep 1
done

if [ -z "$CONTAINER" ]; then
  echo "[daemon] no encontré el contenedor de $BUNDLE" >&2
  exit 1
fi

MAILBOX="$CONTAINER/Documents/screenshots"
echo "[daemon] buzón: $MAILBOX"

# El test recrea el buzón al arrancar; esperamos a que exista.
for _ in $(seq 1 600); do
  [ -d "$MAILBOX" ] && break
  sleep 0.5
done

echo "[daemon] a la escucha"
IDLE=0
while [ "$IDLE" -lt 1200 ]; do   # 10 min sin peticiones → salimos
  shopt -s nullglob
  reqs=("$MAILBOX"/*.request)
  shopt -u nullglob
  if [ ${#reqs[@]} -eq 0 ]; then
    IDLE=$((IDLE + 1))
    sleep 0.5
    continue
  fi
  IDLE=0
  for req in "${reqs[@]}"; do
    name=$(basename "$req" .request)
    rm -f "$req"
    if xcrun simctl io "$UDID" screenshot --type=png "$OUT/$name.png" >/dev/null 2>&1; then
      echo "📸  $OUT/$name.png"
    else
      echo "[daemon] fallo capturando $name" >&2
    fi
    touch "$MAILBOX/$name.done"
  done
done

echo "[daemon] fin (sin peticiones)"
