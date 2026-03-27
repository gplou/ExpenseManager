import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:productivity_app/core/errors/failures.dart';
import 'package:productivity_app/core/network/authenticated_repository.dart';

import '../helpers/mocks.dart';

/// Concrete test class that uses the mixin.
class _TestRepo with AuthenticatedRepository {
  _TestRepo(this._client);
  final SupabaseClient _client;

  @override
  SupabaseClient get client => _client;
}

/// Minimal fake User to satisfy the currentUser getter.
class _FakeUser extends Fake implements User {
  _FakeUser(this.id);

  @override
  final String id;
}

void main() {
  late MockSupabaseClient mockClient;
  late MockGoTrueClient mockAuth;
  late _TestRepo repo;

  setUp(() {
    mockClient = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    when(() => mockClient.auth).thenReturn(mockAuth);
    repo = _TestRepo(mockClient);
  });

  group('AuthenticatedRepository.userId', () {
    test('returns user id when authenticated', () {
      when(() => mockAuth.currentUser).thenReturn(_FakeUser('user-123'));

      expect(repo.userId, 'user-123');
    });

    test('throws AuthFailure when no user is signed in', () {
      when(() => mockAuth.currentUser).thenReturn(null);

      expect(() => repo.userId, throwsA(isA<AuthFailure>()));
    });
  });
}
