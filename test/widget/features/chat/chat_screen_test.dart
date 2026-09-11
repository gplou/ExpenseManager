import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:expense_manager/features/chat/data/chat_repository.dart';
import 'package:expense_manager/features/chat/presentation/chat_screen.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

import '../../../helpers/mocks.dart';

Widget _wrap(MockChatRepository repo) => ProviderScope(
      overrides: [
        chatRepositoryProvider.overrideWithValue(repo),
        isProProvider.overrideWithValue(true), // hide ad banner
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('es'),
        home: const ChatScreen(),
      ),
    );

void main() {
  setUpAll(registerCommonFallbacks);

  late MockChatRepository repo;

  setUp(() {
    repo = MockChatRepository();
  });

  testWidgets('renders the welcome state with title and 3 suggestion chips',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    // Welcome view shows the title plus three ActionChip suggestions.
    expect(find.byType(ActionChip), findsNWidgets(3));
    // The input placeholder is rendered.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(PhosphorIcons.paperPlaneTilt()), findsOneWidget);
  });

  testWidgets('typing + tapping send invokes the repository', (tester) async {
    when(() => repo.sendMessage(
          message: any(named: 'message'),
          history: any(named: 'history'),
          locale: any(named: 'locale'),
        )).thenAnswer((_) async => '¡Hola!');

    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '¿Cuánto gasté en marzo?');
    await tester.tap(find.byIcon(PhosphorIcons.paperPlaneTilt()));
    await tester.pump();

    verify(() => repo.sendMessage(
          message: '¿Cuánto gasté en marzo?',
          history: any(named: 'history'),
          locale: 'es',
        )).called(1);
  });

  testWidgets('tapping a suggestion chip sends that text immediately',
      (tester) async {
    when(() => repo.sendMessage(
          message: any(named: 'message'),
          history: any(named: 'history'),
          locale: any(named: 'locale'),
        )).thenAnswer((_) async => 'ok');

    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    final firstChip = find.byType(ActionChip).first;
    final chipText =
        (tester.widget<ActionChip>(firstChip).label as Text).data;

    await tester.tap(firstChip);
    await tester.pump();

    verify(() => repo.sendMessage(
          message: chipText!,
          history: any(named: 'history'),
          locale: 'es',
        )).called(1);
  });

  testWidgets('empty input does not invoke the repository', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(PhosphorIcons.paperPlaneTilt()));
    await tester.pump();

    verifyNever(() => repo.sendMessage(
          message: any(named: 'message'),
          history: any(named: 'history'),
          locale: any(named: 'locale'),
        ));
  });
}
