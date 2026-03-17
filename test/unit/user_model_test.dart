import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/features/auth/domain/user_model.dart';

void main() {
  group('UserModel', () {
    test('creates with required fields', () {
      final model = UserModel(
        id: 'u1',
        email: 'test@example.com',
        createdAt: DateTime(2024, 1, 1),
      );
      expect(model.id, 'u1');
      expect(model.email, 'test@example.com');
      expect(model.name, isNull);
      expect(model.isEmailVerified, isFalse);
    });

    test('creates with all fields', () {
      final model = UserModel(
        id: 'u1',
        email: 'test@example.com',
        name: 'John',
        avatarUrl: 'https://example.com/avatar.png',
        isEmailVerified: true,
        createdAt: DateTime(2024, 1, 1),
      );
      expect(model.name, 'John');
      expect(model.avatarUrl, 'https://example.com/avatar.png');
      expect(model.isEmailVerified, isTrue);
    });

    test('copyWith creates new instance', () {
      final original = UserModel(
        id: 'u1',
        email: 'test@example.com',
        createdAt: DateTime(2024, 1, 1),
      );
      final updated = original.copyWith(name: 'Updated');
      expect(updated.name, 'Updated');
      expect(updated.id, 'u1');
    });

    test('fromJson creates model from map', () {
      final json = {
        'id': 'u1',
        'email': 'test@example.com',
        'name': 'Test User',
        'avatarUrl': null,
        'isEmailVerified': true,
        'createdAt': '2024-01-01T00:00:00.000',
      };
      final model = UserModel.fromJson(json);
      expect(model.id, 'u1');
      expect(model.email, 'test@example.com');
      expect(model.name, 'Test User');
      expect(model.isEmailVerified, isTrue);
    });
  });
}
