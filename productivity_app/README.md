# 🚀 Productivity App — Flutter MVP

App de productividad y gestión construida con Flutter + Supabase.

## Stack tecnológico

| Categoría | Tecnología |
|---|---|
| Framework | Flutter 3.x |
| Backend | Supabase |
| Estado | Riverpod + riverpod_annotation |
| Navegación | GoRouter |
| Modelos | Freezed + json_serializable |

## Estructura del proyecto

```
lib/
├── core/                    # Código compartido global
│   ├── config/              # AppConfig, Router
│   ├── theme/               # AppTheme, AppColors
│   ├── errors/              # Failures (errores tipados)
│   ├── network/             # Supabase client provider
│   └── utils/               # Extensions
│
├── features/
│   ├── auth/                # Login, registro, sesión
│   ├── tasks/               # CRUD de tareas
│   └── dashboard/           # Pantalla principal
│
└── main.dart
```

## Primeros pasos

### 1. Configurar Supabase

1. Crea un proyecto en [supabase.com](https://supabase.com)
2. Ve a **SQL Editor** y ejecuta el contenido de `supabase_migration.sql`
3. Copia tu **Project URL** y **anon key** desde Project Settings > API

### 2. Configurar variables de entorno

Crea un archivo `.env` en la raíz (o usa `--dart-define`):

```bash
# Opción A: dart-define al correr la app
flutter run \
  --dart-define=SUPABASE_URL=https://tu-proyecto.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=tu-anon-key

# Opción B: edita directamente lib/core/config/app_config.dart (solo para dev)
```

### 3. Instalar dependencias

```bash
flutter pub get
```

### 4. Generar código (freezed + riverpod)

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 5. Agregar fuentes

Descarga la fuente **Sora** de [Google Fonts](https://fonts.google.com/specimen/Sora) y colócala en `assets/fonts/`.

Archivos necesarios:
- `Sora-Regular.ttf`
- `Sora-Medium.ttf`
- `Sora-SemiBold.ttf`
- `Sora-Bold.ttf`

### 6. Crear carpetas de assets

```bash
mkdir -p assets/images assets/icons assets/fonts
```

### 7. Correr la app

```bash
flutter run
```

## Convenciones del proyecto

- **Providers**: siempre en `presentation/providers/` dentro de cada feature
- **Errores**: usar `AppFailure` y sus subclases, nunca lanzar `Exception` cruda
- **Navegación**: usar siempre las constantes de `AppRoutes`
- **Estilos**: usar `context.textTheme`, `context.colors` via las extensions de `BuildContext`
- **Generación de código**: después de modificar modelos o providers con anotaciones, correr `build_runner`

## Añadir un nuevo feature

1. Crear carpeta `lib/features/nombre_feature/`
2. Crear subcarpetas `data/`, `domain/`, `presentation/{screens,widgets,providers}/`
3. Definir el modelo con `@freezed` en `domain/`
4. Crear el contrato (`abstract interface class`) en `domain/`
5. Implementar el repositorio en `data/`
6. Crear providers con `@riverpod` en `presentation/providers/`
7. Construir las pantallas en `presentation/screens/`
8. Añadir las rutas en `core/config/router.dart`

## Testing

```bash
# Unit tests
flutter test

# Tests de un feature específico
flutter test test/features/tasks/
```