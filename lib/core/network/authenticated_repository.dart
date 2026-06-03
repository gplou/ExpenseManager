import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:expense_manager/core/errors/failures.dart';

/// Mixin for repositories that require an authenticated user.
///
/// Provides a shared [userId] getter that throws [AuthFailure]
/// if no user is currently signed in.
mixin AuthenticatedRepository {
  SupabaseClient get client;

  String get userId {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthFailure('User not authenticated');
    return user.id;
  }
}
