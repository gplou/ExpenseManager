# QA manual "conducido en vivo" — mecánica y entorno

Este directorio (`tool/qa/plan/`) es un plan de pruebas manual pensado para que
**Claude Code lo ejecute conduciendo la app real en un emulador**, tocando la
pantalla como lo haría una persona — no es una suite `integration_test`
(esas ya existen en `integration_test/` y cubren otra cosa: regresión rápida
en CI). Este documento es el que se lee primero, siempre, antes de cualquier
sección numerada.

## Cómo se dispara una ejecución

Cuando el usuario diga algo como "ejecuta el plan de pruebas" (o similar,
puede no ser literal):

1. Leer este archivo entero.
2. Preguntar (o asumir por defecto si el usuario no matiza) qué alcance
   ejecutar: todo el plan (01→11 en orden) o solo una sección concreta.
3. Seguir el pre-vuelo de la sección "Entorno" antes de tocar nada.
4. Ejecutar sección por sección, en orden, generando un informe nuevo en
   `tool/qa/results/<YYYY-MM-DD_HHmm>/report.md` (ver "Informe de
   resultados" más abajo). No editar nunca los archivos de `tool/qa/plan/`
   como parte de una ejecución — son estáticos.
5. Los casos marcados `REQUIERE HUMANO` (sección 11 y algunos sueltos en
   otras secciones) se saltan por defecto con veredicto `SKIPPED` — solo se
   ejecutan si el usuario los pide explícitamente por su ID.
6. Los casos marcados `BLOCKED` de antemano (fixture ausente, hardware no
   disponible) se registran como `BLOCKED` sin intentarlo.
7. Al terminar, dar al usuario el resumen (tabla PASS/FAIL/BLOCKED/SKIPPED/
   FLAKY) y la ruta del informe completo — no pegar los 100+ casos en el
   chat.

## Entorno y pre-vuelo

`adb` no está en el `PATH` por defecto en este entorno — usar la ruta
completa `~/Library/Android/sdk/platform-tools/adb` (confirmado presente en
esta máquina) o exportar `PATH="$PATH:$HOME/Library/Android/sdk/platform-tools"`
al principio de la sesión.

Requiere un emulador Android arrancado (API 34 recomendado, igual que CI) y
la app compilada con:

```bash
fvm flutter run --dart-define-from-file=dart_defines.json --dart-define-from-file=dart_defines_e2e.json
```

(o `flutter install` + lanzar por intent si ya está compilada). Antes de
empezar cualquier sección:

```bash
adb devices                                            # confirmar emulador conectado
adb shell wm size                                      # resolución real (escalar coords si difiere)
adb shell dumpsys package com.gpm.expensemanager_app | grep versionName
```

Registrar el resultado de estos tres comandos en la cabecera del informe.

**iOS queda fuera del modo autónomo por defecto.** En este entorno no hay
`idb` instalado ni permisos de Accesibilidad de macOS concedidos para
`cliclick`/AppleScript, así que no hay forma fiable de inyectar toques en el
simulador. Como mucho: `xcrun simctl io booted screenshot` para un pase de
solo-verificación-visual de 3-4 pantallas clave (prompt ATT, botón Apple
Sign-In, safe areas), marcado explícitamente como no-interactivo en el
informe.

## Bucle de interacción por paso (Android / adb)

1. **Ver**: `adb exec-out screencap -p > <scratchpad>/step_NN.png` y leer la
   imagen (localización visual de botones/texto/iconos/estados de carga).
2. **Localizar con precisión** cuando la imagen es ambigua (iconos pequeños,
   listas densas, elementos solapados):
   ```bash
   adb shell uiautomator dump /sdcard/window_dump.xml
   adb pull /sdcard/window_dump.xml <scratchpad>/
   ```
   Buscar el nodo por `text=`/`content-desc=` y usar el centro de su
   `bounds="[x1,y1][x2,y2]"` como coordenada de tap. Esto es un
   **complemento** del screenshot, no un sustituto — los `TestKeys` de
   `lib/core/constants/test_keys.dart` son `ValueKey` internos de Flutter,
   **no** aparecen en el árbol de accesibilidad de Android, así que solo
   sirven aquí como documentación ("qué widget es cuál"), nunca como
   selector.
3. **Tocar / escribir / gestos**:
   - Tap: `adb shell input tap X Y`
   - Escribir texto: tap en el campo, luego `adb shell input text '...'`
     (escapar espacios y caracteres especiales; para símbolos/emoji en notas,
     si `input text` falla, probar `input keyevent` carácter a carácter)
   - Swipe/scroll: `adb shell input swipe x1 y1 x2 y2 [ms]`
   - Atrás: `adb shell input keyevent 4`
   - Enter/submit: `adb shell input keyevent 66`
4. **Esperar sin sleeps largos fijos**: para llamadas de red/IA reales
   (sync, chat, RevenueCat, parse de voz/imagen), hacer poll corto —
   screenshot, comprobar si sigue habiendo spinner/skeleton, `sleep 2`,
   repetir — hasta un timeout por tipo de operación:
   - Operación local (SQLite, navegación): 10s
   - Red/IA (Supabase, Gemini, RevenueCat): 30s
   Nunca asumir que el siguiente frame ya tiene el resultado.
5. **Verificar**: releer con screenshot (+ `uiautomator dump` si el
   resultado esperado es un texto exacto: snackbar, título de diálogo,
   contador) y comparar contra el "Esperado" del caso.

**Reset duro** (equivalente al `resetLocalState` que usan los tests Dart,
pero desde fuera del proceso):
```bash
adb shell pm clear com.gpm.expensemanager_app
```
Borra BD local, SharedPreferences y almacenamiento seguro; fuerza estado de
primer arranque. Se usa solo al principio de la sección 01 (primer arranque)
y, opcionalmente, al pasar del bloque FREE al bloque PRO.

**Reset suave** entre casos del mismo bloque: logout+login, o simplemente
encadenar (muchos casos son deliberadamente secuenciales — el propio caso lo
indica en "Precondición extra" cuando depende de datos creados por un caso
anterior). No asumir aislamiento total entre casos como sí hace un test
automatizado.

**Deep links** (⚠️ ver nota — `android.intent.action.VIEW` NO simula un tap
real del widget, produce un falso `FAIL`, verificado el 2026-09-16):
```bash
adb shell am start -a es.antonborri.home_widget.action.LAUNCH \
  -n com.gpm.expensemanager_app/.MainActivity \
  -d "expensemanager://widget/add"
# o voice | chat | photo
```
El botón real del widget (`HomeWidgetProvider.kt`) usa
`HomeWidgetLaunchIntent.getActivity()` del paquete `home_widget`, que lanza
con la acción custom `es.antonborri.home_widget.action.LAUNCH` — no con
`android.intent.action.VIEW`. `HomeWidgetPlugin.kt`
(`initiallyLaunchedFromHomeWidget`) comprueba esa acción explícitamente, así
que un intent con la acción `VIEW` (aunque abra la app vía el intent-filter
del `AndroidManifest`) nunca se reconoce como "lanzado desde el widget" y no
dispara ninguna acción. Usar siempre la acción correcta de arriba.

**Airplane mode** (para los casos de sync offline):
```bash
adb shell svc wifi disable && adb shell svc data disable   # activar
adb shell svc wifi enable  && adb shell svc data enable    # desactivar
```

**Huella (App Lock)**: requiere que un humano haya enrolado una huella una
vez en los ajustes del AVD (prerrequisito manual, no ejecutable la primera
vez). El desbloqueo posterior sí es automatizable:
```bash
adb -s emulator-5554 emu finger touch 1
```

## Idioma y moneda fijados

No hay hook programático para fijar el locale como hacen los tests Dart
(`kLocaleKey='en'`). Por eso el primer bloque tras el login inicial (caso
`FR-10` en `01_primer_arranque.md`) pasa por Settings → Language → English y
Settings → Currency → EUR antes de continuar. A partir de ahí, **todos los
pasos del resto del plan referencian cadenas en inglés**, nunca español, para
que el matching visual/textual sea determinista pase lo que pase con el
locale del dispositivo host.

## Cuentas y fixtures

| Identidad | Origen | Uso | Si falta |
|---|---|---|---|
| `E2E_FREE` | `dart_defines_e2e.json` (gitignored, ya existe) — `E2E_EMAIL`/`E2E_PASSWORD` | Todo el bloque FREE (secciones 01-08, 10 parcial) | El plan entero se `BLOCKED` — es el fixture base |
| `E2E_PRO` | `dart_defines_e2e_pro.json` (gitignored, **crear manualmente**: segundo usuario Supabase + entitlement "promotional" concedida a mano desde el dashboard de RevenueCat al `app_user_id` correspondiente — evita sandbox de compra real solo para desbloquear PRO) | Sección 09 y parte de 10 | Esas secciones se marcan `BLOCKED (fixture ausente)`, el resto del plan sigue |
| Cuenta desechable | Se crearía en el momento, solo para `MAN-06` (registro nuevo) | Sección 11 | No aplica — ese caso es `REQUIERE HUMANO` por defecto de todos modos |

**Nunca escribir el email/contraseña reales en el informe de resultados** —
referenciar solo "cuenta E2E_FREE" / "cuenta E2E_PRO". Leer las credenciales
con `Read`/`Bash` desde el `.json` correspondiente solo para teclearlas en el
formulario de login.

Fixtures estáticos en `tool/qa/fixtures/`:
- `test_receipt.jpg` — imagen sintética de un recibo (texto legible: comercio,
  fecha, líneas de artículo, total 17.50) para el flujo de foto/IA, sembrada
  con `adb push tool/qa/fixtures/test_receipt.jpg /sdcard/Pictures/` antes de
  usar el selector "Galería" (si el flujo fuerza cámara en vivo, `BLOCKED`).
- `import_sample.json` / `import_sample.csv` — backups válidos en el formato
  propio de `BackupService` (ver `lib/features/transactions/data/backup_service.dart`),
  usados en las pruebas de import.

## Plantilla de caso

```
### [XX-NN] Título breve del caso
**Requiere:** FREE | PRO (fixture E2E_PRO) | hardware (cámara/mic/biometría) | ninguno
**Bloqueante conocido:** — (o qué limitación de esta sección aplica)
**Severidad si falla:** alta | media | baja

Precondición extra: (solo si difiere de la cabecera de la sección)

Pasos:
1. ...
2. ...

Esperado: ...
Verificar: cómo confirmarlo (screenshot / uiautomator dump / ambos)
Si fluctúa (red/IA): reintentar hasta 3 veces con 3s entre intentos; si
  persiste, marcar FLAKY con qué varió — no FAIL. ("no aplica" si el caso es
  puramente local/determinista)
```

## Informe de resultados (separado del plan)

El plan (`tool/qa/plan/*.md`) es estático — solo cambia cuando cambian las
features de la app. Cada ejecución crea su propio informe, nunca sobrescribe
uno anterior:

```
tool/qa/results/<YYYY-MM-DD_HHmm>/
  report.md
  screenshots/<CASE-ID>.png     # solo evidencia de FAIL/BLOCKED
```

`report.md` empieza con una cabecera (commit/branch, `versionName`, salida
del pre-vuelo, cuentas usadas por nombre lógico, hora inicio/fin), sigue con
una tabla resumen (conteo PASS/FAIL/BLOCKED/SKIPPED/FLAKY + una línea de
motivo por cada FAIL/BLOCKED, para lectura rápida) y termina con el detalle
caso por caso usando el mismo ID del plan, veredicto y notas libres.

Veredictos posibles: `PASS`, `FAIL` (comportamiento incorrecto confirmado),
`BLOCKED` (no se pudo ejecutar por fixture/hardware/cuenta ausente),
`SKIPPED` (marcado de antemano como `REQUIERE HUMANO` y no se pidió
explícitamente), `FLAKY` (pasó tras reintento — anotar qué varió).

## Limitaciones conocidas (no ocultarlas, documentarlas caso a caso)

- **Voz**: sin passthrough de audio real al emulador → `BLOCKED` siempre en
  modo autónomo. Solo se verifica que el punto de entrada (icono de
  micrófono) no esté mal cableado (abre el flujo esperado o el PRO-gate).
- **Foto/recibo**: automatizable solo si el selector permite "Galería"
  (sembrando `test_receipt.jpg`); si fuerza cámara en vivo, `BLOCKED`.
- **Compra real (RevenueCat)**: PRO en sí se desbloquea vía entitlement
  promocional (ver `E2E_PRO` arriba) sin pasar por tienda, pero completar un
  cobro sandbox real es `REQUIERE HUMANO`.
- **Restore purchases con historial real**: requiere que la tienda del
  dispositivo tenga ya una compra sandbox previa → `REQUIERE HUMANO`.
- **Google/Apple Sign-In**: no se automatiza con credenciales reales — riesgo
  de exposición y fragilidad del WebView OAuth. Como mucho se verifica que el
  botón abre el flujo correcto y se cancela; el login efectivo es
  `REQUIERE HUMANO`.
- **Forgot/reset password** y **confirmación de email en registro**: implican
  una bandeja de correo real que Claude no puede leer → `REQUIERE HUMANO`.
- **App Lock/biometría**: automatizable solo tras un enrolamiento manual
  único de huella en el AVD.
- **iOS**: fuera del modo autónomo por defecto (ver "Entorno y pre-vuelo").
- **Borrar cuenta**: destructivo e irreversible sobre un usuario real →
  `REQUIERE HUMANO`, nunca se ejecuta salvo petición explícita y puntual.
