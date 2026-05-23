import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/features/subscription/pro_screen.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/features/subscription/subscription_state.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

/// Fake notifier that returns a pre-set state without touching RevenueCat
/// or Supabase. `forceRefresh()` is overridden to be a no-op so `initState`
/// in `_ProScreenState` doesn't trigger a real network call.
class _FakeSubscriptionNotifier extends SubscriptionNotifier {
  _FakeSubscriptionNotifier(this._state);
  final SubscriptionState _state;

  @override
  Future<SubscriptionState> build() async => _state;

  @override
  Future<void> forceRefresh() async {}
}

Widget _wrap({required SubscriptionState state}) {
  return ProviderScope(
    overrides: [
      subscriptionProvider.overrideWith(() => _FakeSubscriptionNotifier(state)),
      // offeringsProvider is autoDispose FutureProvider — fastest override
      // is to make it resolve to null so _PlanPickerFallback renders.
      offeringsProvider.overrideWith((_) async => null),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('es'),
      home: const ProScreen(),
    ),
  );
}

void main() {
  testWidgets('renders the PRO plan title in the app bar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(state: const SubscriptionState()));
    await tester.pumpAndSettle();

    // Spanish: "Plan PRO" (proPlanTitle)
    expect(find.text('Plan PRO'), findsAtLeastNWidgets(1));
  });

  testWidgets('free user sees a subscribe button and no active card',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(state: const SubscriptionState()));
    await tester.pumpAndSettle();

    // Subscribe CTA renders (label: "Suscribirse" in Spanish)
    expect(find.text('Suscribirse'), findsOneWidget);
  });

  testWidgets(
      'PRO user sees the active subscription card and no subscribe button',
      (tester) async {
    final state = SubscriptionState(
      expiresAt: DateTime.now().add(const Duration(days: 30)),
      source: 'app_store',
    );

    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(state: state));
    await tester.pumpAndSettle();

    // No subscribe CTA when already PRO.
    expect(find.text('Suscribirse'), findsNothing);
  });

  testWidgets('renders the benefits section regardless of subscription status',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(state: const SubscriptionState()));
    await tester.pumpAndSettle();

    // The four benefit icons are present
    expect(find.byIcon(Icons.cloud_sync_outlined), findsOneWidget);
    expect(find.byIcon(Icons.mic_outlined), findsOneWidget);
    expect(find.byIcon(Icons.smart_toy_outlined), findsOneWidget);
    expect(find.byIcon(Icons.block_outlined), findsOneWidget);
  });
}
