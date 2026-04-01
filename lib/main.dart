import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'core/services/analytics_service.dart';
import 'core/config/router.dart';
import 'core/local_db/local_database.dart';
import 'core/providers/locale_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/widget_action_provider.dart';
import 'core/theme/app_theme.dart';
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
  final savedTheme = prefs.getString('theme_mode');
  final systemBrightness =
      WidgetsBinding.instance.platformDispatcher.platformBrightness;
  final initialTheme = savedTheme == 'dark'
      ? ThemeMode.dark
      : savedTheme == 'light'
          ? ThemeMode.light
          : systemBrightness == Brightness.dark
              ? ThemeMode.dark
              : ThemeMode.light;
  final savedLocale = prefs.getString('locale_code');
  final deviceCode =
      WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  const supportedCodes = {'es', 'en', 'fr', 'de'};
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

  await _initRevenueCat();
  await _initPostHog();
  AnalyticsService.track(AnalyticsService.appOpened, {'version': '1.0.0'});

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

/// Extrae la acción ('voice' | 'add') de una URI de widget.
/// URI esperada: expensemanager://widget/voice  o  expensemanager://widget/add
String? _extractWidgetAction(Uri? uri) {
  if (uri == null) return null;
  final segments = uri.pathSegments;
  if (segments.isEmpty) return null;
  final action = segments.first;
  if (action == 'voice' || action == 'add' || action == 'chat' || action == 'photo') return action;
  return null;
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
    // Esperar a que tema y locale carguen antes de quitar el splash
    await Future.wait([
      ref.read(themeModeProvider.future),
      ref.read(localeProvider.future),
    ]);
    FlutterNativeSplash.remove();
  }

  @override
  Widget build(BuildContext context) {
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
