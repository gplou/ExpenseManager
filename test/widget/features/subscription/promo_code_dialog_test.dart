import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/features/subscription/subscription_repository.dart';
import 'package:expense_manager/features/subscription/subscription_state.dart';
import 'package:expense_manager/features/subscription/widgets/promo_code_dialog.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

/// Bypasses the real notifier's `build()` (RevenueCat native calls, not
/// available in a widget test) and its `redeemPromoCode` implementation —
/// this test is only about how [PromoCodeDialog] maps a [PromoCodeException]
/// to on-screen text, already covered notifier-side by
/// `subscription_notifier_test.dart` and repository-side by
/// `subscription_repository_promo_test.dart`.
class _ThrowingSubscriptionNotifier extends SubscriptionNotifier {
  _ThrowingSubscriptionNotifier(this._reason);
  final PromoCodeErrorReason _reason;

  @override
  Future<SubscriptionState> build() async => const SubscriptionState();

  @override
  Future<void> redeemPromoCode(String code) {
    throw PromoCodeException('raw server text (unused)', reason: _reason);
  }
}

Future<void> _pumpDialog(
  WidgetTester tester,
  PromoCodeErrorReason reason,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        subscriptionProvider.overrideWith(
          () => _ThrowingSubscriptionNotifier(reason),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              key: const Key('open-btn'),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const PromoCodeDialog(),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.byKey(const Key('open-btn')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), 'ANYCODE');
  await tester.tap(find.text('Apply'));
  await tester.pumpAndSettle();
}

void main() {
  group(
    'PromoCodeDialog error text (regression: used to show the raw Spanish '
    'server message — e.g. "Código no válido" — regardless of app locale)',
    () {
      testWidgets('invalidCode -> localized English text', (tester) async {
        await _pumpDialog(tester, PromoCodeErrorReason.invalidCode);

        expect(find.text("That code isn't valid."), findsOneWidget);
        expect(find.text('Código no válido'), findsNothing);
      });

      testWidgets('expiredCode -> localized English text', (tester) async {
        await _pumpDialog(tester, PromoCodeErrorReason.expiredCode);

        expect(find.text('That code has expired.'), findsOneWidget);
      });

      testWidgets('exhaustedCode -> localized English text', (tester) async {
        await _pumpDialog(tester, PromoCodeErrorReason.exhaustedCode);

        expect(
          find.text('That code has reached its usage limit.'),
          findsOneWidget,
        );
      });

      testWidgets('alreadyRedeemed -> localized English text', (tester) async {
        await _pumpDialog(tester, PromoCodeErrorReason.alreadyRedeemed);

        expect(
          find.text("You've already redeemed this code."),
          findsOneWidget,
        );
      });

      testWidgets('other -> generic localized fallback, never raw server text',
          (tester) async {
        await _pumpDialog(tester, PromoCodeErrorReason.other);

        expect(
          find.text('Unexpected error. Please try again.'),
          findsOneWidget,
        );
      });
    },
  );
}
