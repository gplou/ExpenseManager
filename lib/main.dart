import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:expense_manager/core/utils/app_logger.dart';

import 'core/config/app_config.dart';
import 'core/config/screenshot_mode.dart';
import 'core/constants/app_constants.dart';
import 'core/services/analytics_service.dart';
import 'core/services/sentry_provider_observer.dart';
import 'core/services/sentry_service.dart';
import 'core/theme/app_colors.dart';
import 'core/config/router.dart';
import 'core/widgets/lock_gate.dart';
import 'core/local_db/local_database.dart';
import 'core/providers/locale_provider.dart' show localeProvider, kLocaleKey, supportedLocales;
import 'core/providers/theme_provider.dart' show themeModeProvider, kThemeModeKey;
import 'core/providers/widget_action_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/network/supabase_client.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/budgets/data/budgets_repository.dart';
import 'features/budgets/data/local_budgets_repository.dart';
import 'features/subscription/subscription_provider.dart';
import 'features/transactions/data/initial_sync_service.dart';
import 'features/transactions/data/local_recurring_transactions_repository.dart';
import 'features/transactions/data/local_transactions_repository.dart';
import 'features/transactions/data/offline_sync_service.dart';
import 'features/transactions/data/recurring_transactions_repository.dart';
import 'features/transactions/data/transactions_repository.dart';
import 'features/transactions/presentation/providers/sync_provider.dart';
import 'features/transactions/presentation/providers/home_widget_sync_provider.dart';
import 'features/transactions/presentation/providers/recurring_reminders_provider.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  // ── Global error capture ───────────────────────────────────────────────────
  // Set BEFORE Sentry.init so Sentry's integrations chain on top of these, and
  // so framework/async errors are still logged when SENTRY_DSN is empty.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogger.log('[FlutterError] ${details.exceptionAsString()}');
    SentryService.captureException(details.exception, stackTrace: details.stack);
  };
  binding.platformDispatcher.onError = (error, stack) {
    AppLogger.log('[PlatformDispatcher] uncaught: $error\n$stack');
    SentryService.captureException(error, stackTrace: stack);
    return true;
  };
  // Release-only: replace Flutter's default grey error box with a neutral
  // fallback. Debug keeps the detailed red box for diagnosis.
  if (!kDebugMode) {
    ErrorWidget.builder = _releaseErrorWidget;
  }

  if (Platform.isAndroid) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge).ignore();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ));
  }

  var step = '0 - binding';
  try {
    AppLogger.log('[main] 1 - binding ok');

    // Detectar si la app fue lanzada desde un widget de pantalla de inicio
    step = '1 - HomeWidget';
    HomeWidget.setAppGroupId('group.com.gpm.expensemanagerapp').ignore();
    final widgetLaunchUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    final initialWidgetAction = _extractWidgetAction(widgetLaunchUri);

    // Pre-cargar tema y locale para evitar flash al inicio
    step = '2 - SharedPreferences';
    final prefs = await SharedPreferences.getInstance();
    AppLogger.log('[main] 2 - prefs ok');
    final savedTheme = prefs.getString(kThemeModeKey);
    final systemBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final initialTheme = savedTheme == 'dark'
        ? ThemeMode.dark
        : savedTheme == 'light'
            ? ThemeMode.light
            : systemBrightness == Brightness.dark
                ? ThemeMode.dark
                : ThemeMode.light;
    final savedLocale = prefs.getString(kLocaleKey);
    final deviceCode =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final supportedCodes = supportedLocales.map((l) => l.code).toSet();
    final resolvedDevice =
        supportedCodes.contains(deviceCode) ? deviceCode : 'en';
    final initialLocale = Locale(savedLocale ?? resolvedDevice);

    step = '3 - DateFormatting';
    await Future.wait([
      initializeDateFormatting('es'),
      initializeDateFormatting('en'),
      initializeDateFormatting('fr'),
      initializeDateFormatting('de'),
    ]);
    AppLogger.log('[main] 3 - date formatting ok');

    step = '4 - AppConfig.validate';
    AppConfig.validate();
    AppLogger.log('[main] 4 - config ok');

    // Pre-warm the local SQLite database in the background so the first
    // non-PRO data fetch has no cold-start penalty.
    step = '4.5 - LocalDatabase';
    LocalDatabase.instance.db.ignore();

    step = '5 - Supabase';
    // Supabase es crítico: auth y el redirect del router dependen de él, así que
    // —a diferencia de AdMob/RevenueCat/PostHog— no podemos continuar sin él.
    // El timeout evita que una red lenta cuelgue runApp() indefinidamente
    // (causa típica de ANR en arranque); el TimeoutException se propaga al
    // catch de abajo, que reporta a Sentry, quita el splash y muestra
    // _InitErrorApp ("no se pudo iniciar, reábrela").
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    ).timeout(const Duration(seconds: 15));
    AppLogger.log('[main] 5 - supabase ok');

    step = '6 - Tracking';
    await _requestTrackingAuthorization();
    AppLogger.log('[main] 6 - tracking ok');

    step = '7 - AdMob';
    try {
      await MobileAds.instance.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          AppLogger.log('[main] AdMob initialization timed out — continuing without ads');
          return InitializationStatus({});
        },
      );
      AppLogger.log('[main] 7 - admob ok');
    } catch (e) {
      AppLogger.log('[main] AdMob initialization failed — continuing without ads: $e');
    }

    step = '8 - RevenueCat';
    try {
      await _initRevenueCat().timeout(
        const Duration(seconds: 10),
        onTimeout: () => AppLogger.log('[main] RevenueCat initialization timed out — continuing without purchases'),
      );
      AppLogger.log('[main] 8 - revenuecat ok');
    } catch (e) {
      AppLogger.log('[main] RevenueCat initialization failed — continuing without purchases: $e');
    }

    step = '9 - PostHog';
    try {
      await _initPostHog();
      AppLogger.log('[main] 9 - posthog ok');
    } catch (e) {
      AppLogger.log('[main] PostHog initialization failed — continuing without analytics: $e');
    }

    step = '10 - PackageInfo';
    final packageInfo = await PackageInfo.fromPlatform();

    step = '10.5 - Sentry';
    try {
      await _initSentry(packageInfo);
      AppLogger.log('[main] 10.5 - sentry ok');
    } catch (e) {
      AppLogger.log('[main] Sentry initialization failed — continuing without error tracking: $e');
    }
    AnalyticsService.track(AnalyticsService.appOpened, {'version': packageInfo.version});

    step = '11 - runApp';
    runApp(
      SentryWidget(
        child: ProviderScope(
          observers: [SentryProviderObserver()],
          overrides: [
            if (initialWidgetAction != null)
              pendingWidgetActionProvider.overrideWith(
                (ref) => initialWidgetAction,
              ),
            // ANDAMIAJE TEMPORAL: modo capturas (ver screenshot_mode.dart).
            // Desbloquea la UI PRO pero mantiene TODA la persistencia en SQLite
            // y apaga el sync, para que la cuenta de demo no escriba ni una
            // fila en Supabase. Sin el no-op de syncProvider, forzar isPro
            // dispararía la migración FREE→PRO (migrateToCloud).
            if (ScreenshotMode.enabled) ...[
              isProProvider.overrideWith((ref) => true),
              // La cuenta de demo no tiene nombre en Supabase y el saludo del
              // dashboard sale como "Hola, usuario". Se pone aquí en vez de
              // escribir el metadata del usuario real.
              currentUserProvider.overrideWith((ref) {
                ref.watch(authStateProvider);
                return ref
                    .watch(authRepositoryProvider)
                    .currentUser
                    ?.copyWith(name: 'Lucía');
              }),
              syncProvider.overrideWith(_NoopSyncNotifier.new),
              offlineSyncServiceProvider.overrideWith((ref) {}),
              initialSyncServiceProvider.overrideWith((ref) {}),
              transactionsRepositoryProvider.overrideWith((ref) {
                final user = ref.watch(currentUserProvider);
                if (user == null) {
                  return TransactionsRepository(
                    ref.watch(supabaseClientProvider),
                  );
                }
                return ref.watch(localTransactionsRepositoryProvider);
              }),
              recurringTransactionsRepositoryProvider.overrideWith((ref) {
                final user = ref.watch(currentUserProvider);
                if (user == null) {
                  return RecurringTransactionsRepository(
                    ref.watch(supabaseClientProvider),
                  );
                }
                return ref.watch(localRecurringTransactionsRepositoryProvider);
              }),
              budgetsRepositoryProvider.overrideWith((ref) {
                final user = ref.watch(currentUserProvider);
                if (user == null) {
                  return SupabaseBudgetsRepository(
                    ref.watch(supabaseClientProvider),
                  );
                }
                return ref.watch(localBudgetsRepositoryProvider);
              }),
            ],
          ],
          child: MyApp(
            initialTheme: initialTheme,
            initialLocale: initialLocale,
          ),
        ),
      ),
    );
    AppLogger.log('[main] 10 - runApp ok');
  } catch (e, stack) {
    AppLogger.log('[main] Fatal initialization error at step "$step": $e\n$stack');
    // Report the init-phase fatal (no-op if Sentry never initialized).
    await SentryService.captureException(e, stackTrace: stack);
    FlutterNativeSplash.remove();
    runApp(_InitErrorApp(error: e, step: step));
  }
}

// ── ANDAMIAJE TEMPORAL: modo capturas ────────────────────────────────────────
// Solo activo con --dart-define=SCREENSHOT_MODE=true. Ver screenshot_mode.dart.
// Desbloquea la UI PRO pero mantiene TODA la persistencia en SQLite y apaga los
// servicios de sync, para que la cuenta de demo no escriba nada en Supabase.
// Borrar junto con screenshot_mode.dart cuando termine la tanda de capturas.

class _NoopSyncNotifier extends SyncNotifier {
  @override
  Future<SyncState> build() async => const SyncState();
}

/// Release-only fallback for widget build/layout/paint errors. Avoids Flutter's
/// default grey box; renders a neutral surface without needing a theme/context.
Widget _releaseErrorWidget(FlutterErrorDetails details) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: ColoredBox(
      color: AppColors.paper,
      child: Center(
        child: Icon(PhosphorIcons.warningCircle(), color: AppColors.graphite, size: 40),
      ),
    ),
  );
}

Future<void> _requestTrackingAuthorization() async {
  if (!Platform.isIOS) return;
  // ANDAMIAJE TEMPORAL: el diálogo ATT es una alerta del sistema y bloquea la
  // automatización de la tanda de capturas.
  if (ScreenshotMode.enabled) return;
  final status = await AppTrackingTransparency.trackingAuthorizationStatus;
  // Solo pedimos permiso si aún no se ha tomado ninguna decisión
  if (status == TrackingStatus.notDetermined) {
    await AppTrackingTransparency.requestTrackingAuthorization();
  }
}

Future<void> _initRevenueCat() async {
  // SECURITY: Use verbose logging only in development. Debug level can leak
  // receipt data, user IDs, and entitlement details into device logs.
  await Purchases.setLogLevel(
    AppConfig.isDevelopment ? LogLevel.debug : LogLevel.warn,
  );
  final config = PurchasesConfiguration(
    defaultTargetPlatform == TargetPlatform.android
        ? AppConfig.revenueCatAndroidKey
        : AppConfig.revenueCatIosKey,
  );
  await Purchases.configure(config);
}

Future<void> _initSentry(PackageInfo packageInfo) async {
  if (AppConfig.sentryDsn.isEmpty) return;
  await SentryFlutter.init((options) {
    options.dsn = AppConfig.sentryDsn;
    options.environment = AppConfig.sentryEnvironment;
    options.release =
        '${packageInfo.packageName}@${packageInfo.version}+${packageInfo.buildNumber}';
    options.tracesSampleRate = AppConfig.isDevelopment ? 1.0 : 0.2;
    options.attachScreenshot = false;
    // No PII y sin capturas: es una app financiera.
    options.sendDefaultPii = false;
    // Adjunta stack trace también en eventos de mensaje (sin excepción).
    options.attachStacktrace = true;
    options.debug = AppConfig.isDevelopment;
    // Los reportes de "OnePlus8Pro" con pantalla 288x448 / archs x86 provienen
    // de emuladores y granjas de testing (pre-launch report de Google Play,
    // revisores de tiendas) que falsifican el modelo. Corre tras el enriquecido
    // nativo, así que device.simulator ya está poblado aquí.
    options.beforeSend = (event, hint) {
      final isSimulator = event.contexts.device?.simulator ?? false;
      if (isSimulator) {
        if (AppConfig.isProduction) return null; // descartar ruido en prod
        event.tags = {...?event.tags, 'simulator': 'true'}; // visible en dev
      }
      // Supabase auto-refreshes the session token in the background. When the
      // device is offline this always fails with a SocketException / host
      // lookup error — expected behaviour, not a real bug worth alerting on.
      final exceptions = event.exceptions ?? [];
      final isOfflineAuthRefresh = exceptions.any((ex) {
        final msg = ex.value ?? '';
        return (msg.contains('Failed host lookup') ||
                msg.contains('SocketException')) &&
            msg.contains('auth/v1/token');
      });
      if (isOfflineAuthRefresh) return null;
      // Riverpod completa el `.future` de un provider que muere en pleno load
      // con este StateError (p. ej. logout/login desmonta
      // allTransactionsProvider mientras carga). Es ruido de teardown sin
      // acción posible: el awaiter o se re-construye (watch) o murió con el
      // mismo scope.
      final isProviderDisposedMidLoad = exceptions.any((ex) =>
          (ex.value ?? '').contains('was disposed during loading state'));
      if (isProviderDisposedMidLoad) return null;
      return event;
    };
  });
}

Future<void> _initPostHog() async {
  if (AppConfig.postHogApiKey.isEmpty) return;
  final posthogConfig = PostHogConfig(AppConfig.postHogApiKey)
    ..host = AppConfig.postHogHost
    ..debug = AppConfig.isDevelopment
    ..captureApplicationLifecycleEvents = true;
  await Posthog().setup(posthogConfig);
}

/// Extrae la acción del widget de la URI de lanzamiento.
/// URI esperada: `expensemanager://widget/<action>`
String? _extractWidgetAction(Uri? uri) {
  if (uri == null) return null;
  final segments = uri.pathSegments;
  if (segments.isEmpty) return null;
  final action = segments.first;
  return WidgetActions.all.contains(action) ? action : null;
}

class _InitErrorApp extends StatelessWidget {
  const _InitErrorApp({required this.error, this.step = ''});

  final Object error;
  final String step;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(PhosphorIcons.warningCircle(), size: 48),
                const SizedBox(height: 16),
                const Text(
                  AppConfig.appName,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                // En release ocultamos el paso interno y el detalle de la
                // excepción para no filtrar rutas, nombres de librerías ni
                // mensajes técnicos al usuario. En debug mostramos todo para
                // diagnosticar.
                if (kDebugMode) ...[
                  if (step.isNotEmpty)
                    Text(
                      'Fallo en paso: $step',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: Colors.orange),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                ] else
                  const Text(
                    'No se pudo iniciar la aplicación. '
                    'Cierra y vuelve a abrirla.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({
    super.key,
    required this.initialTheme,
    required this.initialLocale,
  });

  final ThemeMode initialTheme;
  final Locale initialLocale;

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    _removeSplash();
  }

  Future<void> _removeSplash() async {
    // Wait for theme and locale to load before removing the splash.
    // The 3-second timeout ensures the splash is always removed even if a
    // provider fails or hangs (e.g. SharedPreferences unavailable).
    await Future.wait([
      ref.read(themeModeProvider.future),
      ref.read(localeProvider.future),
    ]).timeout(
      const Duration(seconds: 3),
      onTimeout: () => [ThemeMode.light, const Locale('en')],
    );
    FlutterNativeSplash.remove();
  }

  @override
  Widget build(BuildContext context) {
    // ANDAMIAJE TEMPORAL: siembra datos de demo en SQLite (modo capturas).
    if (ScreenshotMode.enabled) ref.watch(screenshotSeedProvider);
    // Arranca el servicio de sync offline una vez y lo mantiene vivo.
    ref.watch(offlineSyncServiceProvider);
    // Hidrata la BD local desde Supabase en el primer arranque para usuarios PRO.
    ref.watch(initialSyncServiceProvider);
    // Reprograma los recordatorios de recurrentes (no-op con el toggle off).
    ref.watch(recurringRemindersBootstrapProvider);
    // Publica gasto/balance del mes en el home widget tras cada CRUD/sync.
    ref.watch(homeWidgetDataSyncProvider);

    final router = ref.watch(routerProvider);
    final themeMode =
        ref.watch(themeModeProvider).value ?? widget.initialTheme;
    final locale =
        ref.watch(localeProvider).value ?? widget.initialLocale;

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Limita el text scaling del sistema para evitar overflows en displays
      // críticos (importe, balance) sin penalizar a usuarios con texto grande.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final clamped = mq.textScaler.clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.3,
        );
        return MediaQuery(
          data: mq.copyWith(textScaler: clamped),
          // App lock: overlay opaco por encima del Navigator (cubre cualquier
          // ruta/diálogo) cuando el bloqueo biométrico está activado.
          child: LockGate(child: child!),
        );
      },
    );
  }
}
