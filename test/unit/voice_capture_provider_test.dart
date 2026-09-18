import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:expense_manager/core/errors/failures.dart';
import 'package:expense_manager/core/services/voice_input_gateway.dart';
import 'package:expense_manager/features/transactions/data/voice_transaction_parser.dart';
import 'package:expense_manager/features/transactions/domain/parsed_voice_transaction.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/presentation/providers/voice_capture_provider.dart';

import '../helpers/mocks.dart';
import '../helpers/provider_container_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerCommonFallbacks);

  late MockVoiceInputGateway gateway;
  late MockVoiceTransactionParser parser;
  late ProviderContainer container;
  late File tempFile;

  File writeTempFile(List<int> bytes) {
    final file = File(
      '${Directory.systemTemp.path}/voice_capture_test_${DateTime.now().microsecondsSinceEpoch}.wav',
    );
    file.writeAsBytesSync(bytes);
    return file;
  }

  setUp(() {
    gateway = MockVoiceInputGateway();
    parser = MockVoiceTransactionParser();
    when(() => gateway.mimeType).thenReturn('audio/wav');
    when(() => gateway.hasPermission()).thenAnswer((_) async => true);
    when(() => gateway.start()).thenAnswer((_) async {});
    when(() => gateway.cancel()).thenAnswer((_) async {});
    tempFile = writeTempFile(List.filled(8000, 1));
    when(() => gateway.stop()).thenAnswer((_) async => tempFile.path);

    container = makeContainer([
      voiceInputGatewayProvider.overrideWithValue(gateway),
      voiceTransactionParserProvider.overrideWithValue(parser),
    ]);
  });

  tearDown(() {
    try {
      if (tempFile.existsSync()) tempFile.deleteSync();
    } catch (_) {}
  });

  VoiceCaptureNotifier notifier() =>
      container.read(voiceCaptureProvider.notifier);

  group('start', () {
    test('starts recording and returns true on the happy path', () async {
      expect(await notifier().start(), isTrue);
      expect(container.read(voiceCaptureProvider), VoiceCaptureStatus.recording);
      verify(() => gateway.start()).called(1);
    });

    test('returns false and stays idle when permission is denied', () async {
      when(() => gateway.hasPermission()).thenAnswer((_) async => false);
      expect(await notifier().start(), isFalse);
      expect(container.read(voiceCaptureProvider), VoiceCaptureStatus.idle);
      verifyNever(() => gateway.start());
    });

    test('returns false and stays idle when the recorder throws', () async {
      when(() => gateway.start()).thenThrow(StateError('boom'));
      expect(await notifier().start(), isFalse);
      expect(container.read(voiceCaptureProvider), VoiceCaptureStatus.idle);
    });

    // Regression: nothing used to stop a second start() from racing the
    // permission/start round-trip of a first one, letting the recorder be
    // stopped and restarted mid-flight and orphaning the first file.
    test('a second start() while already recording is a no-op', () async {
      expect(await notifier().start(), isTrue);
      expect(await notifier().start(), isFalse);
      verify(() => gateway.start()).called(1);
    });
  });

  group('stopAndProcess', () {
    test('returns null without touching the gateway when nothing is recording',
        () async {
      expect(await notifier().stopAndProcess(), isNull);
      verifyNever(() => gateway.stop());
    });

    test('stops, parses and returns to idle on the happy path', () async {
      when(() => parser.parse(any(), mimeType: any(named: 'mimeType'),
              subcategories: any(named: 'subcategories')))
          .thenAnswer((_) async => const ParsedVoiceTransaction(
                amount: 20,
                type: TransactionType.expense,
                category: 'Comida',
              ));

      await notifier().start();
      final result = await notifier().stopAndProcess();

      expect(result?.amount, 20);
      expect(container.read(voiceCaptureProvider), VoiceCaptureStatus.idle);
      expect(tempFile.existsSync(), isFalse);
    });

    test('returns null and deletes the file when the recording is too short',
        () async {
      tempFile.writeAsBytesSync(const [1, 2, 3]);
      await notifier().start();

      final result = await notifier().stopAndProcess();

      expect(result, isNull);
      expect(tempFile.existsSync(), isFalse);
      verifyNever(() => parser.parse(any(),
          mimeType: any(named: 'mimeType'),
          subcategories: any(named: 'subcategories')));
    });

    test('propagates an AppFailure from the parser and still returns to idle',
        () async {
      when(() => parser.parse(any(), mimeType: any(named: 'mimeType'),
              subcategories: any(named: 'subcategories')))
          .thenThrow(const RateLimitFailure('too many calls'));

      await notifier().start();

      await expectLater(
        () => notifier().stopAndProcess(),
        throwsA(isA<RateLimitFailure>()),
      );
      expect(container.read(voiceCaptureProvider), VoiceCaptureStatus.idle);
    });

    // Regression: nothing used to stop a manual stop tap from racing the
    // auto-stop timer (or a double tap), which used to burn two Gemini
    // calls and two rate-limit tokens for a single recording.
    test('a second concurrent stopAndProcess() call no-ops', () async {
      when(() => parser.parse(any(), mimeType: any(named: 'mimeType'),
              subcategories: any(named: 'subcategories')))
          .thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return const ParsedVoiceTransaction(
          amount: 5,
          type: TransactionType.expense,
          category: 'Otros',
        );
      });

      await notifier().start();
      final first = notifier().stopAndProcess();
      final second = notifier().stopAndProcess();

      expect(await second, isNull);
      expect((await first)?.amount, 5);
      verify(() => gateway.stop()).called(1);
      verify(() => parser.parse(any(),
          mimeType: any(named: 'mimeType'),
          subcategories: any(named: 'subcategories'))).called(1);
    });
  });

  group('cancelIfRecording', () {
    // Regression: dispose() used to call gateway.cancel() unconditionally
    // on a single app-wide recorder shared by two widgets, so closing one
    // screen could kill an unrelated in-flight recording started elsewhere.
    test('is a no-op when nothing is recording', () async {
      notifier().cancelIfRecording();
      verifyNever(() => gateway.cancel());
      expect(container.read(voiceCaptureProvider), VoiceCaptureStatus.idle);
    });

    test('is a no-op once a recording has moved to processing', () async {
      when(() => parser.parse(any(), mimeType: any(named: 'mimeType'),
              subcategories: any(named: 'subcategories')))
          .thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return null;
      });
      await notifier().start();
      final pending = notifier().stopAndProcess();

      notifier().cancelIfRecording();
      verifyNever(() => gateway.cancel());

      await pending;
    });

    test('cancels the gateway and resets to idle while recording', () async {
      await notifier().start();
      notifier().cancelIfRecording();
      verify(() => gateway.cancel()).called(1);
      expect(container.read(voiceCaptureProvider), VoiceCaptureStatus.idle);
    });
  });
}
