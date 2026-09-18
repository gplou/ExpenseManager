import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_manager/core/config/router.dart';
import 'package:expense_manager/core/providers/locale_provider.dart';
import 'package:expense_manager/core/services/image_input_gateway.dart';
import 'package:expense_manager/core/services/voice_input_gateway.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/features/subscription/subscription_state.dart';
import 'package:expense_manager/features/transactions/data/image_transaction_parser.dart';
import 'package:expense_manager/features/transactions/data/voice_transaction_parser.dart';
import 'package:expense_manager/features/transactions/domain/parsed_voice_transaction.dart';
import 'package:expense_manager/features/transactions/presentation/providers/subcategories_provider.dart';
import 'package:expense_manager/features/transactions/presentation/widgets/quick_capture_host.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeProSubscriptionNotifier extends SubscriptionNotifier {
  @override
  Future<SubscriptionState> build() async => SubscriptionState(
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        source: 'google_play',
      );
}

class _FakeLocaleNotifier extends LocaleNotifier {
  @override
  Future<Locale> build() async => const Locale('es');
}

class _FakeVoiceParser extends Fake implements VoiceTransactionParser {
  @override
  Future<ParsedVoiceTransaction?> parse(
    Uint8List audioBytes, {
    String mimeType = 'audio/wav',
    List<Map<String, String>> subcategories = const [],
  }) async =>
      null;
}

class _ThrowingImageParser extends Fake implements ImageTransactionParser {
  @override
  Future<ParsedVoiceTransaction?> parse(String imagePath) async =>
      throw Exception('AI backend down');
}

/// hasPermission() succeeds, but start() throws — reproduces
/// EXPENSE-MANAGER-1G: the recording backend can die (or a permission get
/// revoked) in the gap between the two calls.
class _StartThrowsVoiceGateway extends Fake implements VoiceInputGateway {
  @override
  String get mimeType => 'audio/wav';

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<void> start() async {
    throw PlatformException(
      code: 'recorderNotAvailable',
      message: 'Recording not available on this device',
    );
  }

  @override
  Future<void> cancel() async {}
}

/// Records successfully, but stop() resolves to a file with only a handful
/// of bytes — e.g. an accidental instant tap. This should surface the same
/// "couldn't understand" feedback as a real failed parse, not silently
/// reset.
class _TooShortRecordingVoiceGateway extends Fake implements VoiceInputGateway {
  @override
  String get mimeType => 'audio/wav';

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<void> start() async {}

  @override
  Future<String?> stop() async {
    final file = File(
      '${Directory.systemTemp.path}/qc_voice_short_${DateTime.now().microsecondsSinceEpoch}.wav',
    );
    await file.writeAsBytes(const [1, 2, 3]);
    return file.path;
  }

  @override
  Future<void> cancel() async {}
}

class _FakeImageGateway implements ImageInputGateway {
  _FakeImageGateway(this.path);
  final String path;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async =>
      XFile(path);
}

/// Starts successfully and never resolves stop()/cancel() into idle on its
/// own — stays "recording" until the test explicitly stops it, so the
/// camera-blocked-during-voice guard has something active to block.
class _StaysRecordingVoiceGateway extends Fake implements VoiceInputGateway {
  @override
  String get mimeType => 'audio/wav';

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<void> start() async {}

  @override
  Future<String?> stop() async => null;

  @override
  Future<void> cancel() async {}
}

class _TrackingImageGateway implements ImageInputGateway {
  bool pickCalled = false;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    pickCalled = true;
    return null;
  }
}

/// Monta el host sobre un Navigator real (a través de `rootNavigatorKey`), que
/// es como vive en la app: por encima del Navigator pero usándolo para hojas,
/// diálogos y snackbars.
Widget _wrap({
  required Widget child,
  ImageTransactionParser? imageParser,
  List<Override> extraOverrides = const [],
}) {
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    routes: [GoRoute(path: '/', builder: (_, __) => Scaffold(body: child))],
  );
  return ProviderScope(
    overrides: [
      subscriptionProvider.overrideWith(() => _FakeProSubscriptionNotifier()),
      localeProvider.overrideWith(() => _FakeLocaleNotifier()),
      voiceTransactionParserProvider.overrideWithValue(_FakeVoiceParser()),
      imageTransactionParserProvider
          .overrideWithValue(imageParser ?? _ThrowingImageParser()),
      ...extraOverrides,
    ],
    child: MaterialApp.router(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('es'),
      routerConfig: router,
      builder: (context, inner) => QuickCaptureHost(child: inner!),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('expone las acciones de captura a sus descendientes',
      (tester) async {
    QuickCapture? seen;
    await tester.pumpWidget(_wrap(
      child: Builder(builder: (ctx) {
        seen = QuickCapture.maybeOf(ctx);
        return const SizedBox.shrink();
      }),
    ));
    await tester.pumpAndSettle();

    expect(seen, isNotNull,
        reason: 'la barra inferior y las hojas dependen de alcanzarlo');
  });

  testWidgets('un fallo del parser de imagen muestra un mensaje localizado '
      'genérico, nunca el runtimeType', (tester) async {
    final tmp = File(
        '${Directory.systemTemp.path}/qc_${DateTime.now().microsecondsSinceEpoch}.jpg');
    await tester.runAsync(() => tmp.writeAsBytes(const [1, 2, 3]));

    late QuickCapture capture;
    await tester.pumpWidget(_wrap(
      extraOverrides: [
        imageInputGatewayProvider.overrideWithValue(_FakeImageGateway(tmp.path)),
        allSubcategoriesProvider.overrideWith((ref) async => const []),
      ],
      child: Builder(builder: (ctx) {
        capture = QuickCapture.maybeOf(ctx)!;
        return const SizedBox.shrink();
      }),
    ));
    await tester.pumpAndSettle();

    // La suscripción tiene que estar resuelta o el gate PRO redirige a /pro.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    await container.read(subscriptionProvider.future);
    await tester.pump();
    expect(container.read(isProProvider), isTrue);

    // Todo dentro de runAsync: el pipeline hace IO real sobre el temporal.
    await tester.runAsync(() async {
      capture.startPhoto();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Galería'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pump();
    });
    await tester.pump();

    expect(
      find.text('No se pudo procesar tu solicitud. Inténtalo de nuevo.'),
      findsOneWidget,
    );
    expect(find.textContaining('Exception'), findsNothing);
  });

  testWidgets(
      'start() throwing recorderNotAvailable resets voice state instead '
      'of crashing', (tester) async {
    late QuickCapture capture;
    await tester.pumpWidget(_wrap(
      extraOverrides: [
        voiceInputGatewayProvider.overrideWithValue(_StartThrowsVoiceGateway()),
        allSubcategoriesProvider.overrideWith((ref) async => const []),
      ],
      child: Builder(builder: (ctx) {
        capture = QuickCapture.maybeOf(ctx)!;
        return const SizedBox.shrink();
      }),
    ));
    await tester.pumpAndSettle();

    // La suscripción tiene que estar resuelta o el gate PRO redirige a /pro.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    await container.read(subscriptionProvider.future);
    await tester.pump();
    expect(container.read(isProProvider), isTrue);

    capture.startVoice();
    await tester.pumpAndSettle();

    // No unhandled exception reaches the test zone (pumpAndSettle would fail
    // the test) and the user gets an actionable snackbar.
    expect(find.text('Micrófono no disponible'), findsOneWidget);
  });

  // Regression: an accidental instant tap (or a recording the backend
  // couldn't actually capture) used to reset the voice state silently — the
  // user never learned their voice input wasn't understood.
  testWidgets(
      'a too-short recording shows an actionable message instead of '
      'silently resetting', (tester) async {
    late QuickCapture capture;
    await tester.pumpWidget(_wrap(
      extraOverrides: [
        voiceInputGatewayProvider
            .overrideWithValue(_TooShortRecordingVoiceGateway()),
        allSubcategoriesProvider.overrideWith((ref) async => const []),
      ],
      child: Builder(builder: (ctx) {
        capture = QuickCapture.maybeOf(ctx)!;
        return const SizedBox.shrink();
      }),
    ));
    await tester.pumpAndSettle();

    // La suscripción tiene que estar resuelta o el gate PRO redirige a /pro.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    await container.read(subscriptionProvider.future);
    await tester.pump();
    expect(container.read(isProProvider), isTrue);

    capture.startVoice();
    await tester.pumpAndSettle();

    // Tapping the recording overlay stops it and triggers processing — the
    // fake gateway does real file IO, so this needs runAsync plus a real
    // (not fake-clock) delay to let that IO actually complete.
    await tester.runAsync(() async {
      await tester.tap(find.byIcon(PhosphorIcons.stop()));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });
    await tester.pumpAndSettle();

    expect(
      find.text('No se pudo interpretar. Inténtalo de nuevo.'),
      findsOneWidget,
    );
  });

  // Regression: _processImage used to overwrite _voiceState unconditionally,
  // silently taking over from an active recording (and its auto-stop timer's
  // guard) so the recorder never stopped and the mic stayed on indefinitely.
  testWidgets(
      'starting the camera while voice is recording is blocked instead of '
      'silently taking over', (tester) async {
    late QuickCapture capture;
    final imageGateway = _TrackingImageGateway();
    await tester.pumpWidget(_wrap(
      extraOverrides: [
        voiceInputGatewayProvider.overrideWithValue(_StaysRecordingVoiceGateway()),
        imageInputGatewayProvider.overrideWithValue(imageGateway),
        allSubcategoriesProvider.overrideWith((ref) async => const []),
      ],
      child: Builder(builder: (ctx) {
        capture = QuickCapture.maybeOf(ctx)!;
        return const SizedBox.shrink();
      }),
    ));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    await container.read(subscriptionProvider.future);
    await tester.pump();

    capture.startVoice();
    await tester.pumpAndSettle();
    expect(find.byIcon(PhosphorIcons.stop()), findsOneWidget);

    capture.startPhoto();
    await tester.pumpAndSettle();

    expect(imageGateway.pickCalled, isFalse);
    expect(find.text('Galería'), findsNothing);
    // The voice recording is untouched — still showing as active.
    expect(find.byIcon(PhosphorIcons.stop()), findsOneWidget);
  });
}
