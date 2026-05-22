import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:expense_manager/features/auth/domain/auth_repository_contract.dart';
import 'package:expense_manager/features/chat/data/chat_repository.dart';
import 'package:expense_manager/features/subscription/domain/subscription_repository_contract.dart';
import 'package:expense_manager/features/transactions/data/image_transaction_parser.dart';
import 'package:expense_manager/features/transactions/data/voice_transaction_parser.dart';
import 'package:expense_manager/features/transactions/domain/cloud_transaction_sync_contract.dart';
import 'package:expense_manager/features/transactions/domain/custom_categories_repository_contract.dart';
import 'package:expense_manager/features/transactions/domain/recurring_transactions_repository_contract.dart';
import 'package:expense_manager/features/transactions/domain/transactions_repository_contract.dart';

// ── Supabase ─────────────────────────────────────────────────────────────────

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockFunctionsClient extends Mock implements FunctionsClient {}

class MockSupabaseSession extends Mock implements Session {}

class MockSupabaseUser extends Mock implements User {}

class MockAuthResponse extends Mock implements AuthResponse {}

// ── HTTP ─────────────────────────────────────────────────────────────────────

class MockHttpClient extends Mock implements http.Client {}

class MockHttpResponse extends Mock implements http.Response {}

// ── Auth ─────────────────────────────────────────────────────────────────────

class MockAuthRepository extends Mock implements AuthRepositoryContract {}

class MockSocialAuth extends Mock implements SocialAuthContract {}

// ── Chat ─────────────────────────────────────────────────────────────────────

class MockChatRepository extends Mock implements ChatRepository {}

// ── Transactions ─────────────────────────────────────────────────────────────

class MockTransactionsRepository extends Mock
    implements TransactionsRepositoryContract {}

class MockTransactionReader extends Mock implements TransactionReader {}

class MockTransactionWriter extends Mock implements TransactionWriter {}

class MockCloudTransactionSync extends Mock
    implements CloudTransactionSyncContract {}

class MockRecurringTransactionsRepository extends Mock
    implements RecurringTransactionsRepositoryContract {}

class MockCustomCategoriesRepository extends Mock
    implements CustomCategoriesRepositoryContract {}

class MockVoiceTransactionParser extends Mock
    implements VoiceTransactionParser {}

class MockImageTransactionParser extends Mock
    implements ImageTransactionParser {}

// ── Subscription ─────────────────────────────────────────────────────────────

class MockSubscriptionRepository extends Mock
    implements SubscriptionRepositoryContract {}

class MockSupabaseSubscription extends Mock
    implements SupabaseSubscriptionContract {}

class MockRevenueCat extends Mock implements RevenueCatContract {}

class MockPackage extends Mock implements Package {}

class MockOffering extends Mock implements Offering {}

class MockOfferings extends Mock implements Offerings {}

class MockCustomerInfo extends Mock implements CustomerInfo {}

class MockEntitlementInfo extends Mock implements EntitlementInfo {}

// ── Fallback registry ────────────────────────────────────────────────────────

/// Registers fallback values for every mocked type that takes complex
/// parameters by reference or by name. Call once from `setUpAll` in tests
/// that use `any()` / `any(named: ...)` matchers with these types.
///
/// Safe to call multiple times — mocktail dedupes registrations.
void registerCommonFallbacks() {
  registerFallbackValue(DateTime(2026));
  registerFallbackValue(Duration.zero);
  registerFallbackValue(Uri());
  registerFallbackValue(MockPackage());
  registerFallbackValue(<String, dynamic>{});
  registerFallbackValue(<String, String>{});
}
