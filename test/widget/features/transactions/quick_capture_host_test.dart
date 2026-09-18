import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

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
    String transcription, {
    required String langCode,
    List<Map<String, String>> subcategories = const [],
  }) async =>
      null;
}

class _ThrowingImageParser extends Fake implements ImageTransactionParser {
  @override
  Future<ParsedVoiceTransaction?> parse(String imagePath) async =>
      throw Exception('AI backend down');
}

/// initialize() reports the recognizer as available, but listen() throws —
/// reproduces EXPENSE-MANAGER-1G: the OS speech service can die (or a
/// permission get revoked) in the gap between the two calls.
class _ListenThrowsVoiceGateway extends Fake implements VoiceInputGateway {
  @override
  Future<bool> initialize({SpeechErrorListener? onError}) async => true;

  @override
  Future<void> listen({
    required String localeId,
    required SpeechResultListener onResult,
  }) {
    throw PlatformException(
      code: 'recognizerNotAvailable',
      message: 'Speech recognition not available on this device',
    );
  }

  @override
  Future<void> stop() async {}
}

/// initialize() succeeds, but the recognizer reports a transient "couldn't
/// understand" error (e.g. no speech / no match) once listening starts,
/// instead of ever calling onResult — this is `speech_to_text`'s normal way
/// of saying it heard nothing useful, not a hard failure.
class _NoMatchVoiceGateway extends Fake implements VoiceInputGateway {
  SpeechErrorListener? _onError;

  @override
  Future<bool> initialize({SpeechErrorListener? onError}) async {
    _onError = onError;
    return true;
  }

  @override
  Future<void> listen({
    required String localeId,
    required SpeechResultListener onResult,
  }) async {
    _onError?.call(SpeechRecognitionError('error_no_match', false));
  }

  @override
  Future<void> stop() async {}
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
      'listen() throwing recognizerNotAvailable resets voice state instead '
      'of crashing', (tester) async {
    late QuickCapture capture;
    await tester.pumpWidget(_wrap(
      extraOverrides: [
        voiceInputGatewayProvider.overrideWithValue(_ListenThrowsVoiceGateway()),
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

  // Regression: the recognizer's onError callback (wired via initialize(),
  // but invoked by speech_to_text for the whole listening session) reset
  // the voice state without ever telling the user their speech wasn't
  // understood — it just silently went back to idle.
  testWidgets(
      'a transient "no speech understood" error shows an actionable '
      'message instead of silently resetting', (tester) async {
    late QuickCapture capture;
    await tester.pumpWidget(_wrap(
      extraOverrides: [
        voiceInputGatewayProvider.overrideWithValue(_NoMatchVoiceGateway()),
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

    expect(
      find.text('No se pudo interpretar. Inténtalo de nuevo.'),
      findsOneWidget,
    );
  });
}
