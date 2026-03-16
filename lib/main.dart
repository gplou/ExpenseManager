import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'core/config/router.dart';
import 'core/providers/locale_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  // Pre-cargar tema y locale para evitar flash al inicio
  final prefs = await SharedPreferences.getInstance();
  final savedTheme = prefs.getString('theme_mode');
  final initialTheme = savedTheme == 'dark' ? ThemeMode.dark : ThemeMode.light;
  final savedLocale = prefs.getString('locale_code');
  final initialLocale = Locale(savedLocale ?? 'es');

  await Future.wait([
    initializeDateFormatting('es'),
    initializeDateFormatting('en'),
    initializeDateFormatting('fr'),
    initializeDateFormatting('de'),
  ]);

  AppConfig.validate();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  runApp(
    ProviderScope(
      child: MyApp(
        initialTheme: initialTheme,
        initialLocale: initialLocale,
      ),
    ),
  );
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
