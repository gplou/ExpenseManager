import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:expense_manager/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/subscription/subscription_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../services/analytics_route_observer.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/transactions/domain/parsed_voice_transaction.dart';
import '../../features/transactions/presentation/screens/add_transaction_screen.dart';
import '../../features/transactions/presentation/screens/transactions_list_screen.dart';
import '../../features/charts/presentation/screens/charts_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/subscription/pro_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/settings/app_settings_screen.dart';
import '../../features/settings/legal_screen.dart';
import 'legal_content.dart';

part 'router.g.dart';

// Rutas nombradas — evita hardcodear strings por toda la app
abstract class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const dashboard = '/dashboard';
  static const transactions = '/transactions';
  static const addTransaction = '/transactions/add';
  static const charts = '/charts';
  static const pro = '/pro';
  static const chat = '/chat';
  static const onboarding = '/onboarding';
  static const appSettings = '/settings';
  static const privacyPolicy = '/privacy-policy';
  static const termsOfService = '/terms-of-service';
}

/// Notifier que escucha el stream de auth y notifica a GoRouter para
/// que re-evalúe el redirect sin necesidad de recrear el router completo.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Pure redirect logic, extracted so it can be unit-tested without pumping
/// the full router (which would require mocking every screen's providers).
///
/// Returns the path to redirect to, or `null` to allow the navigation.
@visibleForTesting
String? resolveRedirect({
  required Uri uri,
  required String matchedLocation,
  required bool isLoggedIn,
}) {
  // expensemanager://widget/* originates from the home-screen widget.
  // The action was already captured in main.dart via pendingWidgetActionProvider;
  // here we just bounce to the dashboard so GoRouter doesn't treat the URI
  // as an unknown route. Any other host/path is rejected to prevent abuse.
  if (uri.scheme == 'expensemanager') {
    if (uri.host == 'widget') return AppRoutes.dashboard;
    return AppRoutes.login;
  }

  final isAuthRoute = matchedLocation == AppRoutes.login ||
      matchedLocation == AppRoutes.register;

  if (!isLoggedIn && !isAuthRoute) return AppRoutes.login;
  if (isLoggedIn && isAuthRoute) return AppRoutes.dashboard;
  return null;
}

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  final authRepo = ref.read(authRepositoryProvider);

  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    debugLogDiagnostics: kDebugMode,
    observers: [AnalyticsRouteObserver(), SentryNavigatorObserver()],
    // Al cambiar el auth state, GoRouter re-evalúa redirect sin recrearse
    refreshListenable: _RouterRefreshNotifier(authRepo.authStateChanges),
    redirect: (context, state) => resolveRedirect(
      uri: state.uri,
      matchedLocation: state.matchedLocation,
      isLoggedIn: authRepo.currentUser != null,
    ),
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.transactions,
        name: 'transactions',
        builder: (context, state) => const TransactionsListScreen(),
      ),
      GoRoute(
        path: AppRoutes.addTransaction,
        name: 'addTransaction',
        builder: (context, state) => AddTransactionScreen(
          voiceData: state.extra is ParsedVoiceTransaction
              ? state.extra as ParsedVoiceTransaction
              : null,
        ),
      ),
      GoRoute(
        path: AppRoutes.charts,
        name: 'charts',
        builder: (context, state) => const ChartsScreen(),
      ),
      GoRoute(
        path: AppRoutes.pro,
        name: 'pro',
        builder: (context, state) => const ProScreen(),
      ),
      GoRoute(
        path: AppRoutes.chat,
        name: 'chat',
        redirect: (context, state) =>
            ref.read(isProProvider) ? null : AppRoutes.pro,
        builder: (context, state) => const ChatScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.appSettings,
        name: 'appSettings',
        builder: (context, state) => const AppSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.privacyPolicy,
        name: 'privacyPolicy',
        builder: (context, state) => LegalScreen(
          title: AppLocalizations.of(context).privacyPolicy,
          content: privacyPolicyContent,
        ),
      ),
      GoRoute(
        path: AppRoutes.termsOfService,
        name: 'termsOfService',
        builder: (context, state) => LegalScreen(
          title: AppLocalizations.of(context).termsOfService,
          content: termsOfServiceContent,
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text(AppLocalizations.of(context).pageNotFound(state.error.toString())),
      ),
    ),
  );
}
