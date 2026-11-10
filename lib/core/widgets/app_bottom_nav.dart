import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:expense_manager/core/theme/app_elevation.dart';
import 'package:expense_manager/core/utils/extensions.dart';
import 'package:expense_manager/core/widgets/motion/motion.dart';
import 'package:expense_manager/features/transactions/presentation/widgets/quick_capture_host.dart';
import 'package:expense_manager/features/tutorial/tutorial_keys.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

/// Barra inferior de cinco huecos: cuatro pestañas y el botón de alta en el
/// centro.
///
/// No usa `NavigationBar` de Material porque el hueco central no es un
/// destino: es un botón que abre una hoja y no cambia de pestaña. El tema sí
/// aporta los colores (`navigationBarTheme`), para no duplicar tokens.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onSelect,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;

  static const double _fabSize = 60;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final navTheme = Theme.of(context).navigationBarTheme;

    return Container(
      color: navTheme.backgroundColor,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavItem(
                icon: PhosphorIcons.house,
                activeIcon: PhosphorIcons.houseFill,
                label: l10n.navHome,
                selected: currentIndex == 0,
                onTap: () => onSelect(0),
              ),
              _NavItem(
                icon: PhosphorIcons.listBullets,
                activeIcon: PhosphorIcons.listBullets,
                label: l10n.navActivity,
                selected: currentIndex == 1,
                onTap: () => onSelect(1),
              ),
              const _FabSlot(),
              _NavItem(
                icon: PhosphorIcons.target,
                activeIcon: PhosphorIcons.targetFill,
                label: l10n.navBudgets,
                selected: currentIndex == 2,
                onTap: () => onSelect(2),
              ),
              _NavItem(
                icon: PhosphorIcons.chartBar,
                activeIcon: PhosphorIcons.chartBarFill,
                label: l10n.navInsights,
                selected: currentIndex == 3,
                onTap: () => onSelect(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final color = selected ? context.colors.primary : appColors.textMuted;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Al activarse, el icono da un pequeño salto (1.0 → 1.12 → 1.0)
              // y el color se funde en lugar de cambiar de golpe.
              PressableScale(
                pressedScale: 0.85,
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(selected),
                  tween: Tween(begin: selected ? 0 : 1, end: 1),
                  duration: MotionTokens.reduced(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 280),
                  builder: (context, t, child) => Transform.scale(
                    scale: 1 + 0.12 * math.sin(math.pi * t),
                    child: child,
                  ),
                  child: TweenAnimationBuilder<Color?>(
                    tween: ColorTween(end: color),
                    duration: const Duration(milliseconds: 200),
                    builder: (context, c, _) => Icon(
                      selected ? activeIcon : icon,
                      size: 22,
                      color: c,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.1,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hueco central: botón de alta de transacción.
///
/// Siempre abre la hoja manual directamente — voz y foto viven como botones
/// dentro de [AddTransactionScreen] (además del acceso directo desde el
/// widget de pantalla de inicio).
///
/// Lleva [TutorialKeys.fabKey] porque el tutorial mide el objetivo de su
/// primer paso con esa key, y los flujos E2E la usan como señal de "hemos
/// llegado al dashboard". Al vivir en el shell hay una única instancia en
/// toda la app, en vez de una por montaje del dashboard.
class _FabSlot extends StatelessWidget {
  const _FabSlot();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final capture = QuickCapture.maybeOf(context);
    final accent = context.colors.primary;

    return Expanded(
      child: Center(
        child: Semantics(
          button: true,
          label: l10n.fabOpenMenu,
          child: SizedBox(
            key: TutorialKeys.fabKey,
            width: AppBottomNav._fabSize,
            height: AppBottomNav._fabSize,
            child: PressableScale(
              pressedScale: 0.88,
              // El halo va fuera del Material: su clip circular (necesario
              // para que la onda del InkWell no se salga) recortaría la sombra.
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: AppElevation.tinted(accent, opacity: 0.22),
                ),
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    splashColor: accent.withValues(alpha: 0.28),
                    highlightColor: accent.withValues(alpha: 0.12),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      capture?.openAddSheet();
                    },
                    child: Ink(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withValues(alpha: 0.14),
                        border: Border.all(color: accent, width: 1.5),
                      ),
                      child: Icon(
                        PhosphorIcons.plus,
                        color: accent,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
