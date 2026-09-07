# Andamiaje de capturas de tienda

**Esto es temporal.** Existe solo para generar el material de la ficha de la App
Store / Google Play y no forma parte de la app. Todo está detrás de
`--dart-define=SCREENSHOT_MODE=true`; sin ese flag es código muerto que el
compilador elimina, así que ningún build publicable lo incluye.

```bash
bash tool/screenshots_ios.sh          # → screenshots/ios/*.png
```

## Piezas

| Archivo | Qué hace |
| --- | --- |
| `tool/screenshots_ios.sh` | Punto de entrada: arranca el simulador, fija la barra de estado y lanza las dos pasadas. |
| `tool/screenshots/screenshots_test.dart` | Conduce la app pantalla por pantalla y pide una captura en cada parada. |
| `tool/screenshots/daemon.sh` | Lado host: atiende las peticiones y captura con `simctl`. |
| `test_driver/integration_test.dart` | Driver de `flutter drive` (solo arranca `integrationDriver`). |
| `lib/core/config/screenshot_mode.dart` | Flag `SCREENSHOT_MODE` + siembra de datos de demo en SQLite. |
| `lib/main.dart` | Overrides de providers cuando el flag está activo (bloque `if (ScreenshotMode.enabled)`) y salto del diálogo ATT. |

## Decisiones que costaron descubrir

- **Nada toca Supabase.** Forzar `isProProvider = true` desbloquea la UI PRO,
  pero eso a su vez enrutaría las escrituras a la nube y dispararía la migración
  FREE→PRO (`migrateToCloud`). Por eso los overrides también fijan los tres
  repositorios a SQLite, anulan `syncProvider` y apagan los servicios de sync.
  La cuenta de demo no escribe ni una fila en producción.

- **`binding.takeScreenshot()` no sirve.** `integrationDriver` entrega esos bytes
  cuando el test ya ha terminado, así que las 34 capturas salían idénticas, todas
  con la última pantalla. Además la imagen que renderiza el plugin de iOS no
  incluye la barra de estado del sistema. La solución es el buzón de ficheros: el
  test escribe `<nombre>.request` en `Documents/screenshots` —que en el simulador
  es una carpeta normal del Mac— y espera al `.done` que deja el daemon.

- **Sin permisos de Accesibilidad no hay toques.** `cliclick` y AppleScript
  necesitan permisos de macOS que no están concedidos, así que la navegación se
  hace desde Dart (rutas con `GoRouter` + `tester.tap` sobre widgets), no con el
  ratón.

- **El tema hay que fijarlo antes de arrancar.** Pulsar el interruptor de "Modo
  oscuro" durante la tanda dejaba las capturas en claro, así que el modo oscuro
  es una segunda pasada con `SHOT_DARK=true`, que escribe la preferencia antes
  de `app.main()`.

  **No es un bug de la app.** Se comprobó después: `test/unit/theme_mode_wiring_test.dart`
  ejercita el toggle contra `MaterialApp.themeMode` por cuatro vías (con `build()`
  resuelto y sin resolver, sobre la pantalla real de Ajustes, y bajo
  `MaterialApp.router` en una ruta pusheada) y el tema cambia en todas. Lo más
  probable es que el frame nuevo no llegara a la pantalla antes de que
  `simctl io screenshot` disparara desde el host — el repintado por cambio de
  tema afecta a toda la pantalla y `shot()` solo deja 500 ms de margen. La
  segunda pasada sigue siendo la vía fiable, pero por robustez de la captura, no
  por un fallo de la app.

- **El periodo es compartido.** `selectedPeriodProvider` lo usan dashboard y
  gráficos: si dejas los gráficos en vista anual, el dashboard también se queda
  en anual.

- **`tester.drag` sobre un `Scrollable` desplaza la pantalla equivocada** cuando
  hay rutas apiladas con `push` (coge la del dashboard, que sigue viva debajo).
  Se desplaza contra la `ScrollPosition` directamente.

- **Este test vive en `tool/` a propósito**: el workflow `e2e.yml` lanza
  `flutter test integration_test` sobre la carpeta entera y esto reventaría.

## Para quitarlo

```bash
rm -rf tool/screenshots tool/screenshots_ios.sh test_driver
rm lib/core/config/screenshot_mode.dart
```

y en `lib/main.dart` borrar el import de `screenshot_mode.dart`, el bloque
`if (ScreenshotMode.enabled) [...]` de los overrides, la línea
`if (ScreenshotMode.enabled) ref.watch(screenshotSeedProvider);` de `MyApp` y el
early-return de `_requestTrackingAuthorization`.
