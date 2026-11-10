import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'motion_tokens.dart';

/// Onda de audio en vivo: una fila de barras verticales centradas que se
/// desplaza a la izquierda con cada muestra de nivel del micrófono.
///
/// Se alimenta de un [ValueListenable] con el nivel normalizado (0..1), así
/// que solo se mueve cuando llegan muestras reales: sin micro no hay
/// animación infinita (y los tests con `pumpAndSettle` no se quedan colgados).
class AudioLevelWaveform extends StatefulWidget {
  const AudioLevelWaveform({
    super.key,
    required this.level,
    required this.color,
    this.barCount = 28,
    this.height = 56,
    this.barWidth = 3,
    this.minBarHeight = 4,
  });

  final ValueListenable<double> level;
  final Color color;
  final int barCount;
  final double height;
  final double barWidth;
  final double minBarHeight;

  @override
  State<AudioLevelWaveform> createState() => _AudioLevelWaveformState();
}

class _AudioLevelWaveformState extends State<AudioLevelWaveform> {
  late final ListQueue<double> _samples =
      ListQueue<double>.of(List.filled(widget.barCount, 0));

  // Variación fija por barra para que la onda no parezca un ecualizador
  // plano: cada barra amplifica la muestra en distinta medida.
  static const _jitter = [
    0.62,
    0.95,
    0.74,
    1.0,
    0.68,
    0.88,
    0.57,
    0.92,
    0.79,
    0.66,
    0.98,
    0.71,
    0.85,
    0.6,
    0.93,
    0.77,
    0.69,
    1.0,
    0.64,
    0.9,
    0.73,
    0.86,
    0.58,
    0.96,
    0.7,
    0.83,
    0.61,
    0.89,
  ];

  @override
  void initState() {
    super.initState();
    widget.level.addListener(_onLevel);
  }

  @override
  void didUpdateWidget(AudioLevelWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.level != widget.level) {
      oldWidget.level.removeListener(_onLevel);
      widget.level.addListener(_onLevel);
    }
  }

  @override
  void dispose() {
    widget.level.removeListener(_onLevel);
    super.dispose();
  }

  void _onLevel() {
    setState(() {
      _samples.removeFirst();
      _samples.addLast(widget.level.value.clamp(0.0, 1.0));
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MotionTokens.reduced(context);
    final samples = _samples.toList(growable: false);
    final range = widget.height - widget.minBarHeight;

    return ExcludeSemantics(
      child: SizedBox(
        height: widget.height,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < samples.length; i++)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: widget.barWidth / 2),
                child: AnimatedContainer(
                  duration: reduced
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  width: widget.barWidth,
                  height: widget.minBarHeight +
                      range * samples[i] * _jitter[i % _jitter.length],
                  decoration: BoxDecoration(
                    // Las barras más antiguas (izquierda) se apagan un poco:
                    // da sensación de movimiento hacia la izquierda.
                    color: widget.color.withValues(
                      alpha: 0.45 + 0.55 * (i + 1) / samples.length,
                    ),
                    borderRadius: BorderRadius.circular(widget.barWidth),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
