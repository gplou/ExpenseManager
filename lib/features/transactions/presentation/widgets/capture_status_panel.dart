import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import 'package:expense_manager/core/theme/app_spacing.dart';
import 'package:expense_manager/core/utils/extensions.dart';
import 'package:expense_manager/core/widgets/motion/motion.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

/// Fase de una captura por voz o foto, tal y como se pinta en
/// [CaptureStatusPanel].
enum CaptureStatusPhase { listening, processingVoice, processingImage }

/// Tarjeta de estado de una captura por voz/foto: "Escuchando, toca para
/// detener" con la onda del micrófono en vivo (rojo de grabación) y, al
/// parar, "Procesando audio/imagen" con la onda en el color de acento y una
/// barra de progreso indeterminada.
///
/// Compartida por [AddTransactionScreen] (sustituye a la tarjeta del importe
/// mientras dura la captura) y por el overlay de `QuickCaptureHost`.
/// No pinta ningún icono de stop: el botón de parar es de cada pantalla.
class CaptureStatusPanel extends StatelessWidget {
  const CaptureStatusPanel({
    super.key,
    required this.phase,
    required this.level,
    this.onTap,
  });

  final CaptureStatusPhase phase;

  /// Nivel del micrófono 0..1 (ver `VoiceCaptureNotifier.inputLevel`).
  final ValueListenable<double> level;

  /// Toque sobre la tarjeta (mientras escucha: parar y procesar).
  final VoidCallback? onTap;

  /// Rojo de grabación: convención universal de UI, intencionadamente
  /// distinto del coral de "gasto".
  static const Color recordingRed = Color(0xFFE5484D);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = context.colors;
    final listening = phase == CaptureStatusPhase.listening;
    final label = switch (phase) {
      CaptureStatusPhase.listening => l10n.voiceListening,
      CaptureStatusPhase.processingVoice => l10n.voiceProcessing,
      CaptureStatusPhase.processingImage => l10n.imageProcessing,
    };
    final waveColor = listening ? recordingRed : cs.primary;

    return Semantics(
      liveRegion: true,
      button: listening && onTap != null,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: context.appColors.raised,
        borderRadius: AppRadius.radiusLg,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: listening ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    // Punto "REC" que respira con el nivel de voz.
                    ValueListenableBuilder<double>(
                      valueListenable: level,
                      builder: (context, v, _) => AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: waveColor,
                          boxShadow: [
                            BoxShadow(
                              color: waveColor.withValues(
                                alpha: listening ? 0.25 + 0.5 * v : 0.0,
                              ),
                              blurRadius: 4 + 8 * v,
                              spreadRadius: 1 + 3 * v,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Gap(8),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          label.toUpperCase(),
                          key: ValueKey(label),
                          style: context.textTheme.labelMedium?.copyWith(
                            color: context.appColors.textMuted,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const Gap(AppSpacing.sm),
                TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: waveColor),
                  duration: const Duration(milliseconds: 300),
                  builder: (context, c, _) => AudioLevelWaveform(
                    level: level,
                    color: c ?? waveColor,
                    height: 44,
                  ),
                ),
                const Gap(AppSpacing.sm),
                // Indeterminada solo al procesar (ya había un spinner en esa
                // fase); escuchando se queda quieta para no animar sin fin.
                SizedBox(
                  height: 2,
                  child: listening
                      ? null
                      : ClipRRect(
                          borderRadius: AppRadius.radiusPill,
                          child: LinearProgressIndicator(
                            minHeight: 2,
                            color: cs.primary,
                            backgroundColor: cs.primary.withValues(alpha: 0.12),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
