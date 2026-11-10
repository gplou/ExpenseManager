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
