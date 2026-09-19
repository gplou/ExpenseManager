import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/core/network/supabase_client.dart';
import 'package:expense_manager/features/auth/domain/user_model.dart';
import 'package:expense_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:expense_manager/features/budgets/data/budgets_repository.dart';
import 'package:expense_manager/features/budgets/data/local_budgets_repository.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/features/subscription/subscription_state.dart';

import '../../helpers/local_db_helper.dart';
import '../../helpers/mocks.dart';
import '../../helpers/provider_container_helper.dart';

/// [SubscriptionNotifier] whose [build] never completes, so
/// `subscriptionProvider` stays in `AsyncLoading` (no value) for the whole
/// test — reproduces the exact window right after a cold start, before the
/// first subscription fetch resolves.
class _PerpetuallyLoadingSubscription extends SubscriptionNotifier {
  @override
  Future<SubscriptionState> build() => Completer<SubscriptionState>().future;
}

final _fakeUser = UserModel(
  id: 'u1',
  email: 'u1@test.com',
  createdAt: DateTime(2024, 1, 1),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await useInMemoryDatabase();
  });

  test('no session -> direct Supabase repo', () {
    final container = makeContainer([
      supabaseClientProvider.overrideWith((ref) => MockSupabaseClient()),
      currentUserProvider.overrideWith((ref) => null),
    ]);
    expect(
      container.read(budgetsRepositoryProvider),
      isA<SupabaseBudgetsRepository>(),
    );
  });

  test(
    'FREE user stays on LocalBudgetsRepository even while the subscription '
    'is still loading (regression: used to route through '
    'MirroredBudgetsRepository, whose getBudgets() wipes the local mirror '
    'the moment the empty cloud response comes back for a genuine FREE '
    'user)',
    () {
      final container = makeContainer([
        supabaseClientProvider.overrideWith((ref) => MockSupabaseClient()),
        currentUserProvider.overrideWith((ref) => _fakeUser),
        subscriptionProvider.overrideWith(_PerpetuallyLoadingSubscription.new),
      ]);

      expect(
        container.read(budgetsRepositoryProvider),
        isA<LocalBudgetsRepository>(),
      );
    },
  );

  test('confirmed PRO -> MirroredBudgetsRepository', () {
    final container = makeContainer([
      supabaseClientProvider.overrideWith((ref) => MockSupabaseClient()),
      currentUserProvider.overrideWith((ref) => _fakeUser),
      isProProvider.overrideWith((ref) => true),
    ]);

    expect(
      container.read(budgetsRepositoryProvider),
      isA<MirroredBudgetsRepository>(),
    );
  });

  test('confirmed FREE -> LocalBudgetsRepository', () {
    final container = makeContainer([
      supabaseClientProvider.overrideWith((ref) => MockSupabaseClient()),
      currentUserProvider.overrideWith((ref) => _fakeUser),
      isProProvider.overrideWith((ref) => false),
    ]);

    expect(
      container.read(budgetsRepositoryProvider),
      isA<LocalBudgetsRepository>(),
    );
  });
}
