import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_manager/core/config/router.dart';
import 'package:expense_manager/core/providers/locale_provider.dart';
import 'package:expense_manager/core/services/image_input_gateway.dart';
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
    List<Map<String, String>> subcategories = const [],
  }) async =>
      null;
}

class _ThrowingImageParser extends Fake implements ImageTransactionParser {
  @override
  Future<ParsedVoiceTransaction?> parse(
    Uint8List imageBytes, {
    List<Map<String, String>> subcategories = const [],
  }) async =>
      throw Exception('AI backend down');
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
}
