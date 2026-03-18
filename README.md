# ExpenseManager — Gestor de finanzas personales

App móvil de gestión de gastos e ingresos personales construida con Flutter y Supabase. Permite registrar transacciones, visualizar estadísticas, configurar recurrencias y usar IA para añadir movimientos por voz o foto.

---

## Funcionalidades principales

### Transacciones
- Registro de gastos e ingresos con categoría, importe, fecha y notas
- Filtrado por tipo (gasto/ingreso), período y rango de fechas personalizado
- Transacciones recurrentes (diarias, semanales, mensuales) que se procesan automáticamente al arrancar la app
- Categorías personalizadas y subcategorías por usuario
- Exportación a Excel (`.xlsx`) con `share_plus`

### IA integrada
- **Voz**: graba un mensaje de voz → la app transcribe con `speech_to_text` y extrae importe, categoría y nota usando Claude (Anthropic API)
- **Foto**: sube una foto de ticket/factura → se parsea con visión para extraer los datos del gasto
- **Chat financiero**: pantalla de chat para consultar al asistente sobre tus finanzas

### Dashboard
- Resumen de balance, ingresos y gastos del período seleccionado
- Tarjetas de distribución por categoría con gráficos de tarta y barras (`fl_chart`)
- Pull-to-refresh para actualizar datos y procesar recurrentes pendientes
- Tutorial interactivo en el primer uso (spotlight paso a paso)

### Suscripción PRO
- Sistema de suscripción con in-app purchases (`in_app_purchase`)
- Caché de 24h del estado en `SharedPreferences`
- Códigos promocionales canjeables desde la pantalla PRO
- El banner de anuncios se oculta para usuarios PRO
- El botón de voz solo aparece si el usuario es PRO y tiene voz habilitada

### Autenticación
- Email/contraseña, Google Sign-In y Sign in with Apple
- Sesión persistida por Supabase

### Otros
- Widgets de pantalla de inicio (iOS/Android) con `home_widget` — accesos directos a voz, añadir, foto y chat
- Internacionalización completa en 4 idiomas: español, inglés, francés y alemán
- Tema claro/oscuro configurable
- Selector de moneda y formato numérico

---

## Stack tecnológico

| Categoría | Tecnología |
|---|---|
| Framework | Flutter 3.x |
| Backend | Supabase |
| Estado | Riverpod 2.x + riverpod_annotation |
| Navegación | GoRouter |
| Modelos | Freezed + json_serializable |
| Charts | fl_chart 0.69.x |
| IA / Voz | Claude API (Anthropic) + speech_to_text |
| IAP | in_app_purchase 3.x |
| i18n | flutter_localizations + ARB + gen-l10n |
| Persistencia local | SharedPreferences + flutter_secure_storage |
| Widgets nativos | home_widget |
| Exportación | excel + share_plus |

---

## Estructura del proyecto

```
lib/
├── core/
│   ├── config/          # AppConfig, Router, AppRoutes
│   ├── theme/           # AppTheme, AppColors
│   ├── providers/       # theme, locale, currency, number format
│   ├── utils/           # Extensions (DateTime, BuildContext…)
│   └── widgets/         # NeoCard, AdBannerFooter, DateRangePicker…
│
├── features/
│   ├── auth/            # Login, registro, Google/Apple sign-in
│   ├── dashboard/       # Pantalla principal + AppDrawer
│   ├── transactions/    # CRUD, recurrentes, categorías, voz, foto, exportación
│   ├── charts/          # Pantalla de estadísticas avanzadas
│   ├── chat/            # Chat con asistente IA
│   ├── subscription/    # Estado PRO, IAP, pantalla de suscripción
│   ├── onboarding/      # Flujo de bienvenida
│   ├── tutorial/        # Tutorial interactivo con spotlight
│   └── settings/        # Ajustes de la app
│
└── l10n/                # ARB files (es, en, fr, de) + generated
```

---

## Primeros pasos

### 1. Supabase

1. Crea un proyecto en [supabase.com](https://supabase.com)
2. Ejecuta las migraciones SQL necesarias (tablas: `transactions`, `recurring_transactions`, `subscriptions`, `promo_codes`, `promo_code_redemptions`, categorías personalizadas y subcategorías)
3. Copia tu **Project URL** y **anon key** desde Project Settings > API

### 2. Variables de entorno

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://tu-proyecto.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=tu-anon-key \
  --dart-define=ANTHROPIC_API_KEY=tu-api-key
```

O edita directamente `lib/core/config/app_config.dart` para desarrollo local.

### 3. Instalar dependencias

```bash
flutter pub get
```

### 4. Generar código (freezed + riverpod)

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 5. Generar localizaciones

```bash
flutter gen-l10n
```

### 6. Correr la app

```bash
flutter run
```

---

## Convenciones del proyecto

- **Providers**: siempre en `presentation/providers/` dentro de cada feature
- **Errores**: usar `AppFailure` y sus subclases, nunca lanzar `Exception` cruda
- **Navegación**: usar siempre las constantes de `AppRoutes`
- **Estilos**: usar `context.textTheme`, `context.colors` via las extensions de `BuildContext`
- **i18n**: usar siempre `AppLocalizations.of(context)`, nunca strings hardcodeadas en UI
- **Categorías DB**: las claves de categoría se almacenan en español en la BD (ej. `Comida`, `Salario`); la traducción se hace en capa de presentación con `TransactionCategories.localizedName()`
- **Generación de código**: después de modificar modelos o providers con anotaciones, correr `build_runner`

## Añadir un nuevo feature

1. Crear `lib/features/nombre_feature/`
2. Subcarpetas: `data/`, `domain/`, `presentation/{screens,widgets,providers}/`
3. Definir modelo con `@freezed` en `domain/`
4. Crear contrato (`abstract interface class`) en `domain/`
5. Implementar repositorio en `data/`
6. Crear providers con `@riverpod` en `presentation/providers/`
7. Construir pantallas en `presentation/screens/`
8. Añadir rutas en `core/config/router.dart`

## Testing

```bash
# Todos los tests
flutter test

# Tests de un feature
flutter test test/features/transactions/
```
