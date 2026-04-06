import 'package:flutter_test/flutter_test.dart';
import 'package:expense_manager/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('appName is Expense Manager', () {
      expect(AppConfig.appName, 'Expense Manager');
    });

    // Note: supabaseUrl/anonKey are injected via --dart-define so they will
    // be empty in test environment. We test that validate() throws when empty.
    test('validate throws when supabaseUrl is empty', () {
      // In the test environment, SUPABASE_URL is not defined via --dart-define
      // so it defaults to ''. validate() should throw StateError.
      expect(() => AppConfig.validate(), throwsStateError);
    });
  });
}
