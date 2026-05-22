import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/core/config/router.dart';

void main() {
  group('resolveRedirect — logged-out user', () {
    test('protected route → /login', () {
      expect(
        resolveRedirect(
          uri: Uri.parse('/dashboard'),
          matchedLocation: AppRoutes.dashboard,
          isLoggedIn: false,
        ),
        AppRoutes.login,
      );
    });

    test('login route → no redirect', () {
      expect(
        resolveRedirect(
          uri: Uri.parse(AppRoutes.login),
          matchedLocation: AppRoutes.login,
          isLoggedIn: false,
        ),
        isNull,
      );
    });

    test('register route → no redirect', () {
      expect(
        resolveRedirect(
          uri: Uri.parse(AppRoutes.register),
          matchedLocation: AppRoutes.register,
          isLoggedIn: false,
        ),
        isNull,
      );
    });
  });

  group('resolveRedirect — logged-in user', () {
    test('login route → /dashboard (kick user out of auth)', () {
      expect(
        resolveRedirect(
          uri: Uri.parse(AppRoutes.login),
          matchedLocation: AppRoutes.login,
          isLoggedIn: true,
        ),
        AppRoutes.dashboard,
      );
    });

    test('register route → /dashboard', () {
      expect(
        resolveRedirect(
          uri: Uri.parse(AppRoutes.register),
          matchedLocation: AppRoutes.register,
          isLoggedIn: true,
        ),
        AppRoutes.dashboard,
      );
    });

    test('any protected route → no redirect', () {
      for (final path in [
        AppRoutes.dashboard,
        AppRoutes.transactions,
        AppRoutes.charts,
        AppRoutes.appSettings,
      ]) {
        expect(
          resolveRedirect(
            uri: Uri.parse(path),
            matchedLocation: path,
            isLoggedIn: true,
          ),
          isNull,
          reason: 'should not redirect $path',
        );
      }
    });
  });

  group('resolveRedirect — deep links (expensemanager:// scheme)', () {
    test('widget host → /dashboard regardless of auth', () {
      expect(
        resolveRedirect(
          uri: Uri.parse('expensemanager://widget/voice'),
          matchedLocation: '/anything',
          isLoggedIn: false,
        ),
        AppRoutes.dashboard,
      );
      expect(
        resolveRedirect(
          uri: Uri.parse('expensemanager://widget/photo'),
          matchedLocation: '/anything',
          isLoggedIn: true,
        ),
        AppRoutes.dashboard,
      );
    });

    test('non-widget host → /login (defensive)', () {
      expect(
        resolveRedirect(
          uri: Uri.parse('expensemanager://malicious/path'),
          matchedLocation: '/anything',
          isLoggedIn: true,
        ),
        AppRoutes.login,
      );
    });

    test('bare scheme (no host) → /login', () {
      expect(
        resolveRedirect(
          uri: Uri.parse('expensemanager://'),
          matchedLocation: '/anything',
          isLoggedIn: true,
        ),
        AppRoutes.login,
      );
    });
  });

  group('AppRoutes constants are stable', () {
    test('paths start with /', () {
      for (final p in [
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.dashboard,
        AppRoutes.transactions,
        AppRoutes.addTransaction,
        AppRoutes.charts,
        AppRoutes.pro,
        AppRoutes.chat,
        AppRoutes.onboarding,
        AppRoutes.appSettings,
        AppRoutes.privacyPolicy,
        AppRoutes.termsOfService,
      ]) {
        expect(p, startsWith('/'), reason: p);
      }
    });

    test('addTransaction is nested under transactions', () {
      expect(AppRoutes.addTransaction, startsWith(AppRoutes.transactions));
    });
  });
}
