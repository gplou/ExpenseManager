import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:expense_manager/core/services/home_widget_gateway.dart';
import 'package:expense_manager/features/auth/domain/user_model.dart';
import 'package:expense_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/features/transactions/data/image_transaction_parser.dart';
import 'package:expense_manager/features/transactions/data/voice_transaction_parser.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/domain/transactions_repository_contract.dart';
import 'package:expense_manager/features/transactions/presentation/providers/recurring_transactions_provider.dart';
import 'package:expense_manager/features/transactions/presentation/providers/transactions_provider.dart';

import 'mocks.dart';

/// Builds the long list of overrides needed to render Dashboard / Drawer
/// / QuickAddSheet without crashing in widget tests.
///
/// Defaults are tuned for the most common smoke scenarios: PRO user (so
/// the ad banner is hidden), no signed-in user, empty data. Pass specific
/// values to override per-test.
///
/// The [HomeWidgetGateway] is the only one that *must* be a long-lived
/// mock for the test to work (the dashboard's `initState` subscribes to
/// `widgetClicked` synchronously). Pass a [widgetClickedController] if
/// you want to push deep links from the test; otherwise we provide an
/// empty broadcast stream.
List<Override> dashboardOverrides({
  bool isPro = true,
  UserModel? user,
  TransactionsSummary summary = const TransactionsSummary(income: 0, expense: 0),
  List<TransactionModel> recent = const [],
  StreamController<Uri?>? widgetClickedController,
  MockHomeWidgetGateway? homeWidgetGateway,
}) {
  final gateway = homeWidgetGateway ?? _ensureGateway(widgetClickedController);

  return [
    isProProvider.overrideWithValue(isPro),
    currentUserProvider.overrideWith((ref) => user),
    transactionsSummaryProvider.overrideWith((_) async => summary),
    recentTransactionsProvider.overrideWith((_) async => recent),
    processRecurringTransactionsProvider.overrideWith((_) async {}),
    homeWidgetGatewayProvider.overrideWithValue(gateway),
    // SpeedDialFab is mounted inside Dashboard and reads these in initState.
    // Resolve them to mocks so we never touch the real Supabase client.
    voiceTransactionParserProvider
        .overrideWithValue(MockVoiceTransactionParser()),
    imageTransactionParserProvider
        .overrideWithValue(MockImageTransactionParser()),
  ];
}

MockHomeWidgetGateway _ensureGateway(StreamController<Uri?>? controller) {
  final gateway = MockHomeWidgetGateway();
  final effective = controller ?? StreamController<Uri?>.broadcast();
  when(() => gateway.widgetClicked).thenAnswer((_) => effective.stream);
  if (controller == null) {
    addTearDown(effective.close);
  }
  return gateway;
}
