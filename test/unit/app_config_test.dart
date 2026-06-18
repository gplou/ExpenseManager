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

  group('AppConfig.validateValues', () {
    // Valores completos de producción; cada test rompe uno.
    void callValidate({
      bool isProd = true,
      String supabaseUrl = 'https://x.supabase.co',
      String supabaseAnonKey = 'anon-key',
      String revenueCatAndroidKey = 'rc-android',
      String revenueCatIosKey = 'rc-ios',
      String googleWebClientId = 'google-client-id',
      String admobAndroidBannerUnitId = 'ca-app-pub-real/android',
      String admobIosBannerUnitId = 'ca-app-pub-real/ios',
    }) =>
        AppConfig.validateValues(
          isProd: isProd,
          supabaseUrl: supabaseUrl,
          supabaseAnonKey: supabaseAnonKey,
          revenueCatAndroidKey: revenueCatAndroidKey,
          revenueCatIosKey: revenueCatIosKey,
          googleWebClientId: googleWebClientId,
          admobAndroidBannerUnitId: admobAndroidBannerUnitId,
          admobIosBannerUnitId: admobIosBannerUnitId,
        );

    test('passes with complete production config', () {
      expect(callValidate, returnsNormally);
    });

    test('throws when supabaseUrl is empty (any environment)', () {
      expect(() => callValidate(supabaseUrl: ''), throwsStateError);
      expect(
        () => callValidate(isProd: false, supabaseUrl: ''),
        throwsStateError,
      );
    });

    test('throws when supabaseAnonKey is empty (any environment)', () {
      expect(() => callValidate(supabaseAnonKey: ''), throwsStateError);
    });

    test('production: throws with AdMob TEST ad-unit IDs', () {
      expect(
        () => callValidate(
          admobAndroidBannerUnitId: AppConfig.admobTestAndroidBannerUnitId,
        ),
        throwsStateError,
      );
      expect(
        () => callValidate(
          admobIosBannerUnitId: AppConfig.admobTestIosBannerUnitId,
        ),
        throwsStateError,
      );
    });

    test('production: throws with empty RevenueCat keys', () {
      expect(() => callValidate(revenueCatAndroidKey: ''), throwsStateError);
      expect(() => callValidate(revenueCatIosKey: ''), throwsStateError);
    });

    test('production: throws with empty googleWebClientId', () {
      expect(() => callValidate(googleWebClientId: ''), throwsStateError);
    });

    test('development: test AdMob IDs and empty keys only warn', () {
      expect(
        () => callValidate(
          isProd: false,
          admobAndroidBannerUnitId: AppConfig.admobTestAndroidBannerUnitId,
          admobIosBannerUnitId: AppConfig.admobTestIosBannerUnitId,
          revenueCatAndroidKey: '',
          revenueCatIosKey: '',
          googleWebClientId: '',
        ),
        returnsNormally,
      );
    });
  });
}
