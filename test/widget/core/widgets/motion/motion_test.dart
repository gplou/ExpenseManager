import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/core/widgets/motion/motion.dart';
import 'package:expense_manager/features/transactions/presentation/providers/voice_capture_provider.dart';

Widget _wrap(Widget child, {bool disableAnimations = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(body: Center(child: child)),
      ),
    );

String _fmt(double v) => v.toStringAsFixed(2);
const _style = TextStyle(fontSize: 12);

void main() {
  group('AnimatedAmount.countUpOnMount', () {
    testWidgets('cuenta desde 0 hasta el valor al montarse', (tester) async {
      await tester.pumpWidget(_wrap(const AnimatedAmount(
        value: 100,
        formatter: _fmt,
        style: _style,
        countUpOnMount: true,
      )));
      expect(find.text('0.00'), findsOneWidget);
      expect(find.text('100.00'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('100.00'), findsOneWidget);
    });

    testWidgets('con "reducir movimiento" muestra el valor final directamente',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const AnimatedAmount(
          value: 100,
          formatter: _fmt,
          style: _style,
          countUpOnMount: true,
        ),
        disableAnimations: true,
      ));
      expect(find.text('100.00'), findsOneWidget);
    });

    testWidgets('pulseOnChange anima el cambio y se asienta en el nuevo valor',
        (tester) async {
      Widget amount(double v) => _wrap(AnimatedAmount(
            value: v,
            formatter: _fmt,
            style: _style,
            pulseOnChange: true,
          ));
      await tester.pumpWidget(amount(10));
      expect(find.text('10.00'), findsOneWidget);

      await tester.pumpWidget(amount(35));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('35.00'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('35.00'), findsOneWidget);
    });
  });

  group('AnimatedProgressBar', () {
    double barValue(WidgetTester tester) => tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
        .value!;

    testWidgets('se rellena desde 0 y recorta valores > 1', (tester) async {
      await tester.pumpWidget(_wrap(const SizedBox(
        width: 200,
        child: AnimatedProgressBar(
          value: 1.4,
          color: Colors.amber,
          backgroundColor: Colors.grey,
        ),
      )));
      expect(barValue(tester), 0);

      await tester.pumpAndSettle();
      expect(barValue(tester), 1);
    });
  });

  group('FadeSlideIn', () {
    testWidgets('termina totalmente visible y sin timers pendientes',
        (tester) async {
      await tester.pumpWidget(_wrap(const FadeSlideIn(
        index: 3,
        child: Text('hola'),
      )));
      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, 0);

      await tester.pumpAndSettle();
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    });
  });

  group('HighlightPulse', () {
    testWidgets('no anima al montarse y sí cuando cambia el trigger',
        (tester) async {
      Widget pulse(int trigger) => _wrap(HighlightPulse(
            trigger: trigger,
            color: Colors.purple,
            child: const Text('campo'),
          ));
      await tester.pumpWidget(pulse(0));
      expect(tester.hasRunningAnimations, isFalse);

      await tester.pumpWidget(pulse(1));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
      expect(find.text('campo'), findsOneWidget);
    });
  });

  group('AudioLevelWaveform', () {
    testWidgets('solo se mueve cuando llegan muestras de nivel',
        (tester) async {
      final level = ValueNotifier<double>(0);
      addTearDown(level.dispose);
      await tester.pumpWidget(_wrap(AudioLevelWaveform(
        level: level,
        color: Colors.red,
      )));
      expect(tester.hasRunningAnimations, isFalse);

      level.value = 0.9;
      await tester.pump();
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
    });
  });

  group('RouteCoverScope: no se anima debajo de una hoja', () {
    // Reproduce la app: la pestaña vive en un navegador anidado (como las
    // ramas de StatefulShellRoute) dentro de un RouteCoverScope (AppShell), y
    // la hoja se abre en el navegador raíz.
    final rootKey = GlobalKey<NavigatorState>();

    Widget app(ValueNotifier<double> value, ValueNotifier<int> trigger) =>
        MaterialApp(
          navigatorKey: rootKey,
          home: Scaffold(
            body: RouteCoverScope(
              child: Navigator(
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (_) => Column(children: [
                    ValueListenableBuilder<double>(
                      valueListenable: value,
                      builder: (_, v, __) => AnimatedAmount(
                        value: v,
                        formatter: _fmt,
                        style: _style,
                        pulseOnChange: true,
                      ),
                    ),
                    ValueListenableBuilder<int>(
                      valueListenable: trigger,
                      builder: (_, t, __) => HighlightPulse(
                        trigger: t,
                        color: Colors.amber,
                        child: const Text('barra'),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        );

    Future<void> openRootSheet(WidgetTester tester) async {
      showModalBottomSheet<void>(
        context: rootKey.currentContext!,
        builder: (_) => const SizedBox(height: 200, child: Text('hoja')),
      ).ignore();
      await tester.pumpAndSettle();
    }

    testWidgets('el conteo espera a que se cierre la hoja del navegador raíz',
        (tester) async {
      final value = ValueNotifier<double>(9);
      final trigger = ValueNotifier<int>(0);
      addTearDown(value.dispose);
      addTearDown(trigger.dispose);
      await tester.pumpWidget(app(value, trigger));
      await openRootSheet(tester);

      // Se guarda con la hoja encima: ni cuenta ni destella todavía.
      value.value = 11;
      trigger.value = 1;
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('9.00'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);

      // Al cerrarse la hoja arranca el conteo, ya a la vista.
      rootKey.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('9.00'), findsNothing);
      expect(find.text('11.00'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('11.00'), findsOneWidget);
    });

    testWidgets('sin hoja encima se anima en el acto, como antes',
        (tester) async {
      final value = ValueNotifier<double>(9);
      final trigger = ValueNotifier<int>(0);
      addTearDown(value.dispose);
      addTearDown(trigger.dispose);
      await tester.pumpWidget(app(value, trigger));

      value.value = 11;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('9.00'), findsNothing);
      expect(find.text('11.00'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('11.00'), findsOneWidget);
    });

    testWidgets('una hoja abierta en el mismo navegador también lo tapa',
        (tester) async {
      final value = ValueNotifier<double>(9);
      addTearDown(value.dispose);
      late BuildContext pageContext;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          pageContext = context;
          return Scaffold(
            body: ValueListenableBuilder<double>(
              valueListenable: value,
              builder: (_, v, __) =>
                  AnimatedAmount(value: v, formatter: _fmt, style: _style),
            ),
          );
        }),
      ));
      showModalBottomSheet<void>(
        context: pageContext,
        builder: (_) => const SizedBox(height: 200),
      ).ignore();
      await tester.pumpAndSettle();

      value.value = 11;
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('9.00'), findsOneWidget);

      Navigator.of(pageContext).pop();
      await tester.pumpAndSettle();
      expect(find.text('11.00'), findsOneWidget);
    });

    testWidgets('la barra se congela tapada y avanza al destaparse',
        (tester) async {
      final rootKey = GlobalKey<NavigatorState>();
      final value = ValueNotifier<double>(0.5);
      addTearDown(value.dispose);
      await tester.pumpWidget(MaterialApp(
        navigatorKey: rootKey,
        home: Scaffold(
          body: RouteCoverScope(
            child: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => ValueListenableBuilder<double>(
                  valueListenable: value,
                  builder: (_, v, __) => AnimatedProgressBar(
                    value: v,
                    color: Colors.green,
                    backgroundColor: Colors.grey,
                  ),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      double shown() => tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value!;
      expect(shown(), 0.5);

      showModalBottomSheet<void>(
        context: rootKey.currentContext!,
        builder: (_) => const SizedBox(height: 200),
      ).ignore();
      await tester.pumpAndSettle();
      value.value = 0.9;
      await tester.pumpAndSettle();
      expect(shown(), 0.5);

      rootKey.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(shown(), allOf(greaterThan(0.5), lessThan(0.9)));
      await tester.pumpAndSettle();
      expect(shown(), closeTo(0.9, 1e-9));
    });
  });

  group('VoiceCaptureNotifier.normalizeLevel', () {
    test('mapea dBFS a 0..1 con recorte', () {
      expect(VoiceCaptureNotifier.normalizeLevel(-160), 0);
      expect(VoiceCaptureNotifier.normalizeLevel(-50), 0);
      expect(VoiceCaptureNotifier.normalizeLevel(-5), 1);
      expect(VoiceCaptureNotifier.normalizeLevel(0), 1);
      expect(VoiceCaptureNotifier.normalizeLevel(-27.5), closeTo(0.5, 0.001));
    });
  });
}
