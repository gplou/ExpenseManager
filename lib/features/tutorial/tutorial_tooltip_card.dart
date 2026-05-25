import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import 'tutorial_step.dart';

// ── Sliding dot progress indicator ───────────────────────────────────────────

@visibleForTesting
class TutorialStepDots extends StatelessWidget {
  const TutorialStepDots({
    super.key,
    required this.totalSteps,
    required this.stepIndex,
    required this.isDark,
  });

  final int totalSteps;
  final int stepIndex;
  final bool isDark;

  static const int maxVisible = 5;

  @override
  Widget build(BuildContext context) {
    final activeColor = isDark ? Colors.white : AppColors.dustyTeal;
    final inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.30)
        : AppColors.dustyTeal.withValues(alpha: 0.25);

    final int start = totalSteps <= maxVisible
        ? 0
        : (stepIndex - maxVisible ~/ 2).clamp(0, totalSteps - maxVisible);
    final int end = totalSteps <= maxVisible ? totalSteps : start + maxVisible;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(end - start, (j) {
        final i = start + j;
        final active = i == stepIndex;
        final isEdge =
            totalSteps > maxVisible && (j == 0 || j == end - start - 1);
        final size = active ? 10.0 : 7.0;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: EdgeInsets.only(right: j < end - start - 1 ? 6 : 0),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: active
                ? activeColor
                : isEdge
                    ? inactiveColor.withValues(alpha: isDark ? 0.15 : 0.12)
                    : inactiveColor,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

// ── Tooltip card ──────────────────────────────────────────────────────────────

@visibleForTesting
class TutorialTooltipCard extends StatelessWidget {
  const TutorialTooltipCard({
    super.key,
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.isLast,
    required this.isFirst,
    required this.onNext,
    required this.onBack,
  });

  final TutorialStep step;
  final int stepIndex;
  final int totalSteps;
  final bool isLast;
  final bool isFirst;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E2530) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final subColor = isDark
        ? Colors.white.withValues(alpha: 0.65)
        : const Color(0xFF1A1A2E).withValues(alpha: 0.60);

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 28,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title row
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (step.icon != null) ...[
                  Icon(step.icon, color: AppColors.dustyTeal, size: 20),
                  const Gap(8),
                ],
                Expanded(
                  child: Text(
                    step.title,
                    style: TextStyle(
                      fontFamily: 'GeneralSans',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            const Gap(8),

            // Body
            Text(
              step.body,
              style: TextStyle(
                fontFamily: 'GeneralSans',
                fontSize: 13,
                height: 1.55,
                color: subColor,
              ),
            ),
            const Gap(16),

            // Footer: dot indicators + next button
            Row(
              children: [
                Expanded(
                  child: TutorialStepDots(
                    totalSteps: totalSteps,
                    stepIndex: stepIndex,
                    isDark: isDark,
                  ),
                ),
                const Gap(12),

                // Back button (hidden on first step)
                if (!isFirst) ...[
                  TextButton(
                    onPressed: onBack,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.dustyTeal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontFamily: 'GeneralSans',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_back_rounded, size: 14),
                        const Gap(4),
                        Text(AppLocalizations.of(context).tutorialBack),
                      ],
                    ),
                  ),
                  const Gap(8),
                ],

                // Next / Finish button
                FilledButton(
                  onPressed: onNext,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.dustyTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                      fontFamily: 'GeneralSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(isLast
                          ? AppLocalizations.of(context).tutorialFinish
                          : AppLocalizations.of(context).tutorialNext),
                      if (!isLast) ...[
                        const Gap(4),
                        const Icon(Icons.arrow_forward_rounded, size: 14),
                      ] else ...[
                        const Gap(4),
                        const Icon(Icons.check_rounded, size: 14),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Spotlight CustomPainter ───────────────────────────────────────────────────

@visibleForTesting
class TutorialSpotlightPainter extends CustomPainter {
  const TutorialSpotlightPainter({
    required this.spotlightRect,
    required this.radius,
  });

  final Rect spotlightRect;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final fullScreen =
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final hole = Path()
      ..addRRect(
          RRect.fromRectAndRadius(spotlightRect, Radius.circular(radius)));

    final overlayPath =
        Path.combine(PathOperation.difference, fullScreen, hole);
    canvas.drawPath(
      overlayPath,
      Paint()..color = Colors.black.withValues(alpha: 0.72),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(spotlightRect, Radius.circular(radius)),
      Paint()
        ..color = AppColors.dustyTeal.withValues(alpha: 0.50)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(spotlightRect, Radius.circular(radius)),
      Paint()
        ..color = AppColors.dustyTeal
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }

  @override
  bool shouldRepaint(TutorialSpotlightPainter old) =>
      old.spotlightRect != spotlightRect || old.radius != radius;
}
