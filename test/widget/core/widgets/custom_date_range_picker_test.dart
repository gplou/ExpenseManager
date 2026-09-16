import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/core/widgets/custom_date_range_picker.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

Widget _harness({
  DateTimeRange? Function(DateTimeRange?)? onClosed,
  Locale locale = const Locale('es'),
}) {
  return MaterialApp(
    // AppTheme.lightTheme da minimumSize de ancho infinito a los botones
    // filled/outlined/elevated (pensado para CTAs a ancho completo). Sin
    // este tema, el infinito no aparece y un botón roto dentro de un Row
    // (como el "Aplicar" de _CalendarActions) pasaría el test igual.
    theme: AppTheme.lightTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: locale,
    home: Scaffold(
      body: Builder(
        builder: (context) => FilledButton(
          key: const Key('open-btn'),
          onPressed: () async {
            final result = await showCustomDateRangePicker(
              context: context,
              firstDate: DateTime(2025, 1, 1),
              lastDate: DateTime(2027, 12, 31),
              initialDateRange: DateTimeRange(
                start: DateTime(2026, 5, 10),
                end: DateTime(2026, 5, 20),
              ),
            );
            onClosed?.call(result);
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    // Required so DateFormat('MMMM yyyy', locale) works in tests.
    await initializeDateFormatting('es', null);
    await initializeDateFormatting('en', null);
  });

  Future<void> openPicker(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('open-btn')));
    await tester.pumpAndSettle();
  }

  testWidgets('renders the month label of the initial range', (tester) async {
    await tester.pumpWidget(_harness());
    await openPicker(tester);

    // Capitalised "Mayo 2026" from intl 'es' locale.
    expect(find.text('Mayo 2026'), findsOneWidget);
  });

  testWidgets('next month chevron navigates forward', (tester) async {
    await tester.pumpWidget(_harness());
    await openPicker(tester);

    await tester.tap(find.byIcon(PhosphorIcons.caretRight()).first);
    await tester.pumpAndSettle();

    expect(find.text('Junio 2026'), findsOneWidget);
  });

  testWidgets('previous month chevron navigates backward', (tester) async {
    await tester.pumpWidget(_harness());
    await openPicker(tester);

    await tester.tap(find.byIcon(PhosphorIcons.caretLeft()).first);
    await tester.pumpAndSettle();

    expect(find.text('Abril 2026'), findsOneWidget);
  });

  testWidgets('tapping the header switches to the month-grid view',
      (tester) async {
    await tester.pumpWidget(_harness());
    await openPicker(tester);

    await tester.tap(find.text('Mayo 2026'));
    await tester.pumpAndSettle();

    // Year selector renders just the year number; calendar header is gone.
    expect(find.text('2026'), findsOneWidget);
    expect(find.text('Mayo 2026'), findsNothing);
    // Back button is visible.
    expect(find.text('Volver'), findsOneWidget);
  });

  testWidgets('selecting a month from the grid goes back to calendar view',
      (tester) async {
    await tester.pumpWidget(_harness());
    await openPicker(tester);
    await tester.tap(find.text('Mayo 2026'));
    await tester.pumpAndSettle();

    // Pick a month in the grid (Mar = March).
    await tester.tap(find.text('Mar'));
    await tester.pumpAndSettle();

    expect(find.text('Marzo 2026'), findsOneWidget);
  });

  testWidgets('Cancel pops with null', (tester) async {
    DateTimeRange? captured;
    bool wasCalled = false;
    await tester.pumpWidget(_harness(onClosed: (r) {
      wasCalled = true;
      captured = r;
      return r;
    }));
    await openPicker(tester);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(wasCalled, isTrue);
    expect(captured, isNull);
  });

  testWidgets('selecting two days and confirming returns a DateTimeRange',
      (tester) async {
    DateTimeRange? captured;
    await tester.pumpWidget(_harness(onClosed: (r) => captured = r));
    await openPicker(tester);

    // Tap day 15 → becomes start; tap day 18 → becomes end.
    await tester.tap(find.text('15'));
    await tester.pump();
    await tester.tap(find.text('18'));
    await tester.pump();

    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.start.day, 15);
    expect(captured!.end.day, 18);
  });

  group('locale (regression: month/weekday labels were hardcoded to "es")',
      () {
    testWidgets('renders the month label in the app locale, not Spanish',
        (tester) async {
      await tester.pumpWidget(_harness(locale: const Locale('en')));
      await openPicker(tester);

      expect(find.text('May 2026'), findsOneWidget);
      expect(find.text('Mayo 2026'), findsNothing);
    });

    testWidgets('month-grid abbreviations follow the app locale',
        (tester) async {
      await tester.pumpWidget(_harness(locale: const Locale('en')));
      await openPicker(tester);
      await tester.tap(find.text('May 2026'));
      await tester.pumpAndSettle();

      // English 'MMM' for March is "Mar" too, so assert on a month whose
      // Spanish/English abbreviations differ.
      expect(find.text('Jan'), findsOneWidget);
      expect(find.text('Ene'), findsNothing);
    });

    testWidgets('weekday initials follow the app locale, not the '
        'hardcoded Spanish L M X J V S D', (tester) async {
      await tester.pumpWidget(_harness(locale: const Locale('en')));
      await openPicker(tester);

      // English narrow weekdays starting Monday: M T W T F S S.
      // Spanish 'X' (miércoles) and 'J' (jueves) must not appear.
      expect(find.text('X'), findsNothing);
      expect(find.text('J'), findsNothing);
    });
  });
}
