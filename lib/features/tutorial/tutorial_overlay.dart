import 'package:flutter/material.dart';
import 'package:expense_manager/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  });

  final TutorialStep step;
  final int stepIndex;
  final int totalSteps;
  final bool isLast;
  final bool isFirst;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSkip;

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
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Reencola una medición para el siguiente frame, mientras el paso viva.
  ///
  /// Antes la medición se encolaba desde `build`, así que solo se repetía si
  /// algo provocaba rebuild: al fallar o al estabilizarse dejaba de mirar, y
  /// cualquier cambio de layout posterior (carga del banner de anuncios,
  /// llegada de datos asíncronos, fin de una transición de ruta) dejaba el
  /// spotlight congelado en una posición que ya no era la del objetivo.
  ///
  /// No es un bucle activo: un post-frame callback no provoca frames por sí
  /// mismo, así que en reposo se queda pendiente hasta que haya un frame por
  /// otro motivo. Y el encadenado muere con el widget del paso.
  void _scheduleRemeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measureTarget();
    });
  }

  void _measureTarget() {
    final ctx = widget.step.targetKey.currentContext;
    final box = ctx?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      // El objetivo aún no está en el árbol (datos asíncronos, transición de
      // ruta en curso...). Reintentar en el siguiente frame.
      _scheduleRemeasure();
      return;
    }

    final pos = box.localToGlobal(Offset.zero);
    final newRect =
        Rect.fromLTWH(pos.dx, pos.dy, box.size.width, box.size.height);

    // Durante una transición de ruta `localToGlobal` devuelve coordenadas
    // transformadas: el rect llega y cambia frame a frame. Se sigue midiendo
    // hasta agotar el presupuesto para no congelar el primer valor, que es
    // justo lo que dejaba el spotlight a media pantalla.
    if (newRect != _targetRect) {
      if (mounted) setState(() => _targetRect = newRect);
    }
    _scheduleRemeasure();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final rect = _targetRect;
    final spotlight = rect?.inflate(widget.step.spotlightPadding);

    // Reparto vertical. Sin spotlight (objetivo no medible) la tarjeta va
    // abajo, que es donde cae la mano.
    final spaceBelow = spotlight == null ? 0.0 : screen.height - spotlight.bottom;
    final spaceAbove = spotlight?.top ?? screen.height;
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
            child: spotlight == null
                ? Container(color: Colors.black.withValues(alpha: 0.72))
                : CustomPaint(
                    size: screen,
                    painter: TutorialSpotlightPainter(
                      spotlightRect: spotlight,
                      radius: widget.step.spotlightRadius,
                    ),
                  ),
          ),

          // ── Tap-through on spotlight → advances step ─────────────────────
          if (spotlight != null)
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
            bottom: MediaQuery.paddingOf(context).bottom + 20,
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
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),

          // ── Skip button ──────────────────────────────────────────────────
          Positioned(
            bottom: MediaQuery.paddingOf(context).bottom + 20,
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
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // ── Tooltip card ─────────────────────────────────────────────────
          //
          // El desplazamiento contra el spotlight va como padding de una capa
          // que ocupa toda la pantalla, no como `top`/`bottom` de un
          // `Positioned`. La diferencia importa: un `Positioned` admite
          // valores que dejan la tarjeta fuera de pantalla — y ahí el usuario
          // se queda sin botón con el que seguir, sin más salida que
          // "Omitir". Con padding acotado a [_minCardSpace] la tarjeta
          // siempre cae dentro, aunque el spotlight esté mal medido.
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: tooltipBelow
                      ? _cardInset(spotlight!.bottom + 14, screen)
                      : 0,
                  // Anclada abajo, la tarjeta tiene que dejar libre la fila
                  // del contador y "Omitir" — de ahí el suelo.
                  bottom: tooltipBelow
                      ? 0
                      : _cardInset(
                          spotlight == null
                              ? _controlsReserve
                              : (screen.height - spotlight.top + 14)
                                  .clamp(_controlsReserve, double.infinity),
                          screen,
                        ),
                ),
                child: Align(
                  alignment:
                      tooltipBelow ? Alignment.topCenter : Alignment.bottomCenter,
                  child: SingleChildScrollView(
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
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Espacio mínimo que se le reserva siempre a la tarjeta.
  static const double _minCardSpace = 200;

  /// Alto de la fila inferior (contador de pasos y "Omitir"), que la tarjeta
  /// no debe tapar cuando va anclada abajo.
  static const double _controlsReserve = 56;

  /// Acota el desplazamiento para que nunca deje a la tarjeta sin sitio.
  static double _cardInset(double desired, Size screen) =>
      desired.clamp(0.0, (screen.height - _minCardSpace).clamp(0.0, double.infinity));
}

