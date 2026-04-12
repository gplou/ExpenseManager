import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'core/constants/app_constants.dart';
import 'core/services/analytics_service.dart';
import 'core/config/router.dart';
import 'core/local_db/local_database.dart';
import 'core/providers/locale_provider.dart' show localeProvider, kLocaleKey, supportedLocales;
import 'core/providers/theme_provider.dart' show themeModeProvider, kThemeModeKey;
import 'core/providers/widget_action_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/transactions/data/initial_sync_service.dart';
import 'features/transactions/data/offline_sync_service.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  // Detectar si la app fue lanzada desde un widget de pantalla de inicio
  HomeWidget.setAppGroupId('group.com.gpm.expensemanager_app');
  final widgetLaunchUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
  final initialWidgetAction = _extractWidgetAction(widgetLaunchUri);

  // Pre-cargar tema y locale para evitar flash al inicio
  final prefs = await SharedPreferences.getInstance();
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

  await Future.wait([
    initializeDateFormatting('es'),
    initializeDateFormatting('en'),
    initializeDateFormatting('fr'),
    initializeDateFormatting('de'),
  ]);

  AppConfig.validate();

  // Pre-warm the local SQLite database in the background so the first
  // non-PRO data fetch has no cold-start penalty.
  LocalDatabase.instance.db.ignore();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  await _requestTrackingAuthorization();
  await MobileAds.instance.initialize();
  await _initRevenueCat();
  await _initPostHog();
  final packageInfo = await PackageInfo.fromPlatform();
  AnalyticsService.track(AnalyticsService.appOpened, {'version': packageInfo.version});

  runApp(
    ProviderScope(
      overrides: [
        if (initialWidgetAction != null)
          pendingWidgetActionProvider.overrideWith(
            (ref) => initialWidgetAction,
          ),
      ],
      child: MyApp(
        initialTheme: initialTheme,
        initialLocale: initialLocale,
      ),
    ),
  );
}

Future<void> _requestTrackingAuthorization() async {
  if (!Platform.isIOS) return;
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

Future<void> _initPostHog() async {
  if (AppConfig.postHogApiKey.isEmpty) return;
  final posthogConfig = PostHogConfig(AppConfig.postHogApiKey)
    ..host = AppConfig.postHogHost
    ..debug = AppConfig.isDevelopment
    ..captureApplicationLifecycleEvents = true;
  await Posthog().setup(posthogConfig);
}

/// Extrae la acción del widget de la URI de lanzamiento.
/// URI esperada: expensemanager://widget/<action>
String? _extractWidgetAction(Uri? uri) {
  if (uri == null) return null;
  final segments = uri.pathSegments;
  if (segments.isEmpty) return null;
  final action = segments.first;
  return WidgetActions.all.contains(action) ? action : null;
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
    // Arranca el servicio de sync offline una vez y lo mantiene vivo.
    ref.watch(offlineSyncServiceProvider);
    // Hidrata la BD local desde Supabase en el primer arranque para usuarios PRO.
    ref.watch(initialSyncServiceProvider);

    final router = ref.watch(routerProvider);
    final themeMode =
        ref.watch(themeModeProvider).valueOrNull ?? widget.initialTheme;
    final locale =
        ref.watch(localeProvider).valueOrNull ?? widget.initialLocale;

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
    );
  }
}
