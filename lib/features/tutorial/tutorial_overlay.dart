import 'package:flutter/material.dart';
import 'package:expense_manager/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/theme/app_colors.dart';
import 'tutorial_keys.dart';
import 'tutorial_notifier.dart';
import 'tutorial_step.dart';

// ── Public overlay widget ─────────────────────────────────────────────────────

/// Drop this widget as the **last child** of the top-level Stack that wraps the
/// Scaffold so it can cover the AppBar and the entire screen.
///
/// It is a no-op while the tutorial is inactive, consuming zero pointer events.
class TutorialOverlay extends ConsumerWidget {
  const TutorialOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tut = ref.watch(tutorialProvider);
    final l10n = AppLocalizations.of(context);
    final steps = buildTutorialSteps(l10n);
    final fabRect = ref.watch(fabRectProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      child: tut.isActive
          ? _TutorialOverlayContent(
              key: ValueKey(tut.stepIndex),
              step: steps[tut.stepIndex],
              stepIndex: tut.stepIndex,
              totalSteps: steps.length,
              isLast: tut.isLastStep,
              isFirst: tut.isFirstStep,
              fabRect: fabRect,
              onNext: () => ref.read(tutorialProvider.notifier).next(),
              onBack: () => ref.read(tutorialProvider.notifier).previous(),
              onSkip: () => ref.read(tutorialProvider.notifier).skip(),
            )
          : const SizedBox.shrink(),
    );
  }
}

// ── Per-step overlay content ──────────────────────────────────────────────────

class _TutorialOverlayContent extends StatefulWidget {
  const _TutorialOverlayContent({
    super.key,
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.isLast,
    required this.isFirst,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
    this.fabRect,
  });

  final TutorialStep step;
  final int stepIndex;
  final int totalSteps;
  final bool isLast;
  final bool isFirst;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  /// Pre-computed FAB screen rect (bypasses GlobalKey measurement for the FAB step).
  final Rect? fabRect;

  @override
  State<_TutorialOverlayContent> createState() =>
      _TutorialOverlayContentState();
}

class _TutorialOverlayContentState extends State<_TutorialOverlayContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  Rect? _targetRect;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // If the target widget is not in the tree and the step allows skipping,
      // auto-advance without showing anything to the user.
      if (widget.step.skipIfKeyMissing &&
          widget.step.targetKey.currentContext == null) {
        widget.onNext();
        return;
      }

      // Start the fade-in immediately so the dark backdrop appears at once.
      _ctrl.forward();
      _measureTarget();
    });
  }

  @override
  void didUpdateWidget(_TutorialOverlayContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-measure when the pre-computed FAB rect arrives or changes.
    if (widget.step.targetKey == TutorialKeys.fabKey &&
        widget.fabRect != oldWidget.fabRect &&
        widget.fabRect != null) {
      _measureTarget();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _measureTarget() {
    // For the FAB step the rect is computed directly by _SpeedDialFabState to
    // avoid GlobalKey measurement inaccuracies inside nested Positioned/Stacks.
    if (widget.step.targetKey == TutorialKeys.fabKey) {
      final newRect = widget.fabRect;
      if (newRect != null && mounted && newRect != _targetRect) {
        setState(() => _targetRect = newRect);
      }
      return;
    }

    final ctx = widget.step.targetKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final pos = box.localToGlobal(Offset.zero);
    final newRect = Rect.fromLTWH(pos.dx, pos.dy, box.size.width, box.size.height);
    if (mounted && newRect != _targetRect) {
      setState(() => _targetRect = newRect);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Re-measure every frame so the spotlight tracks the target even if a late
    // layout change (async data load, keyboard dismissal, ad banner, etc.) shifts
    // the widget after the initial measurement.
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureTarget());

    final screen = MediaQuery.of(context).size;
    final rect = _targetRect;

    if (rect == null) {
      // Still measuring – show a semi-transparent backdrop without spotlight.
      return FadeTransition(
        opacity: _fade,
        child: _Backdrop(onTap: widget.onSkip),
      );
    }

    final spotlight = rect.inflate(widget.step.spotlightPadding);

    // Decide whether to show the tooltip above or below the spotlight.
    final spaceBelow = screen.height - spotlight.bottom;
    final spaceAbove = spotlight.top;
    final tooltipBelow = spaceBelow >= 220 && spaceBelow >= spaceAbove;

    return FadeTransition(
      opacity: _fade,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Dark backdrop (blocks all taps outside spotlight) ────────────
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {}, // absorb taps on backdrop
            child: CustomPaint(
              size: screen,
              painter: _SpotlightPainter(
                spotlightRect: spotlight,
                radius: widget.step.spotlightRadius,
              ),
            ),
          ),

          // ── Tap-through on spotlight → advances step ─────────────────────
          Positioned(
            left: spotlight.left,
            top: spotlight.top,
            width: spotlight.width,
            height: spotlight.height,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: widget.onNext,
              child: const SizedBox.expand(),
            ),
          ),

          // ── Step counter ─────────────────────────────────────────────────
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 20,
            left: 20,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                '${widget.stepIndex + 1} / ${widget.totalSteps}',
                style: const TextStyle(
                  fontFamily: 'GeneralSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),

          // ── Skip button ──────────────────────────────────────────────────
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 20,
            right: 20,
            child: TextButton(
              onPressed: widget.onSkip,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                AppLocalizations.of(context).tutorialSkip,
                style: const TextStyle(
                  fontFamily: 'GeneralSans',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),

          // ── Tooltip card ─────────────────────────────────────────────────
          Positioned(
            left: 16,
            right: 16,
            top: tooltipBelow ? spotlight.bottom + 14 : null,
            bottom: tooltipBelow
                ? null
                : screen.height - spotlight.top + 14,
            child: _TooltipCard(
              step: widget.step,
              stepIndex: widget.stepIndex,
              totalSteps: widget.totalSteps,
              isLast: widget.isLast,
              isFirst: widget.isFirst,
              onNext: widget.onNext,
              onBack: widget.onBack,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Plain backdrop (shown while measuring) ────────────────────────────────────

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(color: Colors.black.withValues(alpha: 0.72)),
      );
}

// ── Sliding dot progress indicator ───────────────────────────────────────────

class _StepDots extends StatelessWidget {
  const _StepDots({
    required this.totalSteps,
    required this.stepIndex,
    required this.isDark,
  });

  final int totalSteps;
  final int stepIndex;
  final bool isDark;

  static const int _maxVisible = 5;

  @override
  Widget build(BuildContext context) {
    final activeColor =
        isDark ? Colors.white : AppColors.dustyTeal;
    final inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.30)
        : AppColors.dustyTeal.withValues(alpha: 0.25);

    final int start = totalSteps <= _maxVisible
        ? 0
        : (stepIndex - _maxVisible ~/ 2).clamp(0, totalSteps - _maxVisible);
    final int end =
        totalSteps <= _maxVisible ? totalSteps : start + _maxVisible;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(end - start, (j) {
        final i = start + j;
        final active = i == stepIndex;
        final isEdge = totalSteps > _maxVisible && (j == 0 || j == end - start - 1);
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

// ── Spotlight CustomPainter ───────────────────────────────────────────────────

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({
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

    // Dark overlay with cutout
    final overlayPath =
        Path.combine(PathOperation.difference, fullScreen, hole);
    canvas.drawPath(
      overlayPath,
      Paint()..color = Colors.black.withValues(alpha: 0.72),
    );

    // Glowing halo
    canvas.drawRRect(
      RRect.fromRectAndRadius(spotlightRect, Radius.circular(radius)),
      Paint()
        ..color = AppColors.dustyTeal.withValues(alpha: 0.50)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    // Solid teal border
    canvas.drawRRect(
      RRect.fromRectAndRadius(spotlightRect, Radius.circular(radius)),
      Paint()
        ..color = AppColors.dustyTeal
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.spotlightRect != spotlightRect || old.radius != radius;
}

// ── Tooltip card ──────────────────────────────────────────────────────────────

class _TooltipCard extends StatelessWidget {
  const _TooltipCard({
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
                  child: _StepDots(
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
