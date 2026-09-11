import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:image_picker/image_picker.dart';

import 'package:expense_manager/core/providers/locale_provider.dart';
import 'package:expense_manager/core/services/image_input_gateway.dart';
import 'package:expense_manager/features/transactions/presentation/providers/subcategories_provider.dart';
import 'package:expense_manager/core/widgets/neo_card.dart';
import 'package:expense_manager/features/dashboard/widgets/dashboard_fab.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/features/subscription/subscription_state.dart';
import 'package:expense_manager/features/transactions/data/image_transaction_parser.dart';
import 'package:expense_manager/features/transactions/data/voice_transaction_parser.dart';
import 'package:expense_manager/features/transactions/domain/parsed_voice_transaction.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeSubscriptionNotifier extends SubscriptionNotifier {
  @override
  Future<SubscriptionState> build() async => const SubscriptionState();
}

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

class _FakeImageParser extends Fake implements ImageTransactionParser {
  @override
  Future<ParsedVoiceTransaction?> parse(
    Uint8List imageBytes, {
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

// ── Widget builder ────────────────────────────────────────────────────────────

Widget _buildFab({
  bool isPro = true,
  ImageTransactionParser? imageParser,
  List<Override> extraOverrides = const [],
}) =>
    ProviderScope(
      overrides: [
        subscriptionProvider.overrideWith(
          isPro
              ? () => _FakeProSubscriptionNotifier()
              : () => _FakeSubscriptionNotifier(),
        ),
        localeProvider.overrideWith(() => _FakeLocaleNotifier()),
        voiceTransactionParserProvider.overrideWithValue(_FakeVoiceParser()),
        imageTransactionParserProvider
            .overrideWithValue(imageParser ?? _FakeImageParser()),
        ...extraOverrides,
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('es'),
        home: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(child: SpeedDialFab()),
            ],
          ),
        ),
      ),
    );

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SpeedDialFab — accessibility', () {
    testWidgets('renders a single + FAB with the open-menu semantic label',
        (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(_buildFab());
        await tester.pumpAndSettle();

        expect(find.byType(NeoFab), findsOneWidget);
        expect(
          find.bySemanticsLabel('Abrir menú de acciones'),
          findsOneWidget,
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('FAB Semantics widget has button=true', (tester) async {
      await tester.pumpWidget(_buildFab());
      await tester.pumpAndSettle();

      final fabSemantics = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .firstWhere((s) => s.properties.label == 'Abrir menú de acciones');
      expect(fabSemantics.properties.button, isTrue);
    });

    testWidgets('non-PRO user sees the same single FAB', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(_buildFab(isPro: false));
        await tester.pumpAndSettle();

        expect(find.byType(NeoFab), findsOneWidget);
        expect(
          find.bySemanticsLabel('Abrir menú de acciones'),
          findsOneWidget,
        );
      } finally {
        handle.dispose();
      }
    });
  });

  group('SpeedDialFab — AI error handling (F11)', () {
    testWidgets('image parse failure shows a generic localized snackbar',
        (tester) async {
      final tmp = File(
          '${Directory.systemTemp.path}/fab_test_${DateTime.now().microsecondsSinceEpoch}.jpg');
      await tester.runAsync(() => tmp.writeAsBytes(const [1, 2, 3]));

      await tester.pumpWidget(_buildFab(
        imageParser: _ThrowingImageParser(),
        extraOverrides: [
          imageInputGatewayProvider
              .overrideWithValue(_FakeImageGateway(tmp.path)),
          allSubcategoriesProvider.overrideWith((ref) async => const []),
        ],
      ));
      await tester.pumpAndSettle();

      // Asegura que la suscripción PRO está resuelta antes de tocar (si no,
      // _requirePro() redirigiría a /pro).
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SpeedDialFab)),
      );
      await container.read(subscriptionProvider.future);
      await tester.pump();
      expect(container.read(isProProvider), isTrue);

      // Toda la interacción dentro de runAsync: _startCamera hace IO real
      // (readAsBytes / delete del temporal) que no completa en la zona
      // fake-async del tester.
      await tester.runAsync(() async {
        // Mini-FAB de cámara → bottom sheet de origen → Galería.
        await tester.tap(find.byIcon(PhosphorIcons.camera()));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Galería'));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 250));
        await tester.pump();
      });
      await tester.pump();

      // Mensaje genérico localizado — nunca el runtimeType de la excepción.
      expect(
        find.text('No se pudo procesar tu solicitud. Inténtalo de nuevo.'),
        findsOneWidget,
      );
      expect(find.textContaining('Exception'), findsNothing);
    });
  });
}
