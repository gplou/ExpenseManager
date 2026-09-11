# Theme — Nocturne

Sistema visual actual de la app: interfaz oscura, tranquila y compacta.
Fondo azul-gris casi neutro, tipografía Inter en peso medio, radios
suaves de 8px, acento usado como línea y brillo — nunca como relleno
grande. Evolución in-place del sistema anterior (Quiet Wealth): mismos
ficheros y mismos nombres de token, valores nuevos.

## Ficheros

| Fichero | Qué contiene |
| --- | --- |
| `app_colors.dart` | Paleta canónica (light/dark) + un zoo de aliases legacy reapuntados a esos valores. **Editar solo los ~20 campos canónicos** (`paper`, `surface`, `raised`, `divider`, `borderStrong`, `ink`, `graphite*`, `whisper*`, `inkBlue*`, `positive/negative/warning*` y sus variantes `*Dark`) — todo lo demás sigue el cambio automáticamente. |
| `app_semantic_colors.dart` | `ThemeExtension` que expone `context.appColors.*` (mode-aware) como espejo 1:1 de los campos de `AppColors`. No suele hacer falta tocarlo al cambiar look — solo si se añade un token canónico nuevo que quieras exponer así. |
| `app_spacing.dart` | `AppSpacing` (múltiplos de 4) y `AppRadius` (8/12/16/24/999 — radios suaves). Cambiar aquí para variar la sensación "compacta vs. generosa" de toda la app de una vez. |
| `app_elevation.dart` | `AppElevation.e1/e2/e3` (sombra ambiental única, sin capas) y `AppElevation.tinted(color)` (glow centrado, sin offset — usado en FABs y CTAs). |
| `app_theme.dart` | `ThemeData` completo (claro y oscuro): `ColorScheme`, `TextTheme`, y el theming de cada componente Material. La tipografía vive en `_buildTextTheme` al final del fichero. |

## Cómo variar el look

- **Recolorear (misma estructura)**: cambia los ~20 campos canónicos de
  `app_colors.dart`. `AppTheme` y `AppSemanticColors` los consumen sin
  tocar nada más — así es como se migró de Quiet Wealth a Nocturne.
- **Acento de marca**: `AppColors.inkBlue` (light) / `inkBlueLight` (dark)
  son el acento. `inkBlueSoft`/`inkBlueSoftDark` son su fondo tintado
  (chips seleccionados, CTA de hoja); `inkBlueDeep`/`inkBlueDeepDark` son
  el texto legible sobre ese tinte — siempre más profundo que el acento
  puro para no perder contraste.
- **Radios**: todo pasa por `AppRadius` (`xs/sm/md/lg/xl/xxl/sheet/pill`).
  Cambiar los valores numéricos ahí re-escala cards, botones, inputs,
  bottom sheets y chips a la vez.
- **Tipografía**: familia y pesos están en `app_theme.dart` (`fontFamily:
  'Inter'`, pesos `FontWeight.w400`/`w500` — nunca 600+ en esta escala).
  Los tamaños/tracking de cada rol viven en `_buildTextTheme`. Para
  cambiar de familia tipográfica: añade los `.ttf` a `assets/fonts/`,
  regístralos en `pubspec.yaml` bajo `flutter.fonts`, y cambia el string
  `'Inter'` (hay ~2 sitios: el `fontFamily:` de nivel superior de cada
  `ThemeData` y cada `TextStyle(fontFamily: 'Inter', ...)`).
- **Sombras/glow**: `AppElevation`. `tinted()` es el glow de acento
  (FAB, CTAs) — sin offset, para que lea como brillo y no como sombra.

## Decisiones tomadas (Nocturne)

- **Evolución in-place, no un tema nuevo en un selector.** La app solo
  tenía `ThemeMode` (claro/oscuro), no una lista de "temas" con nombre —
  construir ese selector no se pidió y habría sido un cambio de
  arquitectura, no de estética. Nocturne sustituye a Quiet Wealth
  directamente, mismos tokens, valores nuevos.
- **`positive`/`negative`/`warning` (ok/warn/over) NO usan los valores
  OKLCH literales del spec.** Esos OKLCH (L 0.70–0.74) están pensados
  para texto sobre fondo oscuro; usados tal cual habrían roto el
  contraste en `colorScheme.secondary`/`error` (relleno sólido) y en
  light mode. Se mantuvieron los tonos existentes — ya comparten familia
  de matiz (verde/ámbar/coral apagados) y funcionan en ambos modos vía
  el patrón color-base + `*Soft` ya establecido.
- **Inter va empaquetado como `.ttf` (`assets/fonts/`), no vía
  `google_fonts`.** Se probó primero con el paquete `google_fonts`
  (fetch en runtime); se cambió a bundling estático por dos motivos: (1)
  esta app es offline-first (SQLite + sync), depender de red para la
  tipografía básica no encaja; (2) `google_fonts` con fetch en runtime
  rompe los golden tests (la regla del repo es no tocar red desde
  `test/`). El bundling sigue exactamente el patrón ya usado para
  GeneralSans.
- **El token "keypad" (`#292b31`) del spec no es un campo nuevo** — se
  fusionó con `AppColors.raisedDark`, que ya era el fondo que usa
  `NumericKeypad` para sus teclas.
- **`NeoFab` ya era el "FAB con glow"** que pedía el spec — no se creó
  un widget nuevo. Lo único que cambió es que el glow estaba
  desactivado a propósito en modo oscuro (`isDark ? null : tinted(...)`,
  heredado de Quiet Wealth); Nocturne lo quiere siempre visible, así que
  ahora se muestra en ambos modos (también en los mini-FAB de
  mic/cámara en `dashboard_fab.dart`).
- **`AppChip`/`AppStatCard` se crearon pero no se forzaron en pantallas
  existentes.** Los tres candidatos obvios (`PeriodChip`/`IconChip` en
  `period_selector.dart`, `_QuickChip` en `recent_categories_strip.dart`,
  `ChartStatCard`) tienen comportamiento deliberadamente distinto de un
  chip/stat-card genérico (colores por-instancia, estado seleccionado
  sin acento a propósito, compuestos con estados de carga) — sustituirlos
  habría cambiado decisiones de diseño ya razonadas, no solo estética.
  Quedan disponibles para pantallas nuevas.
- **Migración de iconos a Phosphor excluye el picker de categorías**
  (`transaction_categories.dart`, `pickableIcons`/`income`/`expense`) y
  todo `Icons.label_outlined` usado como fallback de categoría. Esos
  `IconData` se persisten como codePoint entero en Supabase/SQLite
  asumiendo la fuente Material — migrarlos habría corrompido los iconos
  de categorías personalizadas ya guardadas.
- **Peso tipográfico inline pendiente de limpieza**: ~70 sitios fuera de
  `app_theme.dart` todavía usan `FontWeight.w600`/`w700` a mano en
  `TextStyle` propios (no leen el `TextTheme`). Se corrigió el
  `fontFamily` de esos mismos sitios (quedaban en `'GeneralSans'`), pero
  capar el peso a 400/500 ahí es un cambio de mayor volumen que requiere
  revisar jerarquía visual caso a caso — se deja como trabajo pendiente,
  no se hizo un barrido a ciegas.

## Golden tests

`test/golden/` tiene 8 imágenes (4 pantallas × claro/oscuro). Se generan
en macOS y **se excluyen de CI** (`--exclude-tags golden` en
`ci.yml`) porque el renderizado de fuentes de Skia difiere lo bastante
entre macOS y `ubuntu-latest` como para dar falsos positivos. Correrlos:

```bash
fvm flutter test test/golden/                  # comparar contra baseline
fvm flutter test test/golden/ --update-goldens # regenerar baseline
fvm flutter test --exclude-tags golden         # lo que corre CI
```

Los iconos Phosphor salen como cuadraditos en los PNG (el bundle de
`flutter test` no expone la fuente del paquete de iconos) — es una
limitación conocida y cosmética del harness de test, no un bug; los
iconos se verificaron aparte en un simulador real.
