import 'package:flutter/material.dart';
import 'package:expense_manager/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tutorial_keys.dart';
import 'tutorial_notifier.dart';
import 'tutorial_step.dart';
import 'tutorial_tooltip_card.dart';

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
              painter: TutorialSpotlightPainter(
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
            child: TutorialTooltipCard(
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

