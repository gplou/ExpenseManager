import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:productivity_app/features/chat/data/chat_repository.dart';
import 'package:productivity_app/features/transactions/domain/transactions_repository_contract.dart';
import 'package:productivity_app/features/transactions/domain/recurring_transactions_repository_contract.dart';
import 'package:productivity_app/features/transactions/domain/custom_categories_repository_contract.dart';
import 'package:productivity_app/features/subscription/domain/subscription_repository_contract.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockChatRepository extends Mock implements ChatRepository {}

class MockTransactionsRepository extends Mock
    implements TransactionsRepositoryContract {}

class MockRecurringTransactionsRepository extends Mock
    implements RecurringTransactionsRepositoryContract {}

class MockCustomCategoriesRepository extends Mock
    implements CustomCategoriesRepositoryContract {}

class MockSubscriptionRepository extends Mock
    implements SubscriptionRepositoryContract {}
