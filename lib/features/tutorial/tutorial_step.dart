import 'package:flutter/material.dart';

import 'tutorial_keys.dart';

/// Metadata for a single tutorial step.
class TutorialStep {
  const TutorialStep({
    required this.title,
    required this.body,
    required this.targetKey,
    this.icon,
    this.spotlightPadding = 14.0,
    this.spotlightRadius = 18.0,
    this.measureDelay = Duration.zero,
  });

  /// Short bold heading shown in the tooltip card.
  final String title;

  /// Descriptive body text shown in the tooltip card.
  final String body;

  /// [GlobalKey] of the widget to spotlight.
  final GlobalKey targetKey;

  /// Optional icon shown next to the title in the tooltip card.
  final IconData? icon;

  /// Extra padding (px) added around the target rect for the spotlight hole.
  final double spotlightPadding;

  /// Corner radius of the spotlight rounded-rect.
  final double spotlightRadius;

  /// Delay before measuring the target widget's position.
  /// Use this for widgets that animate into place (e.g. SpeedDial mini buttons)
  /// so the spotlight is measured after the animation finishes.
  final Duration measureDelay;
}

/// The ordered list of all tutorial steps shown to the user.
///
/// Note: cannot use `const` because [GlobalKey] instances are not
/// compile-time constants.
final List<TutorialStep> kTutorialSteps = [
  // ── 0 · Main FAB ──────────────────────────────────────────────────────────
  TutorialStep(
    title: 'Añade transacciones',
    body:
        'Toca el botón + para desplegar las opciones de registro. '
        'Puedes añadir con voz, manualmente o fotografiando un recibo.',
    targetKey: TutorialKeys.fabKey,
    icon: Icons.add_circle_outline_rounded,
    spotlightPadding: 10,
    spotlightRadius: 32,
  ),

  // ── 1 · Voice ─────────────────────────────────────────────────────────────
  TutorialStep(
    title: '🎤 Añadir con voz',
    body:
        'Di en voz alta el importe, la categoría, la subcategoría y una descripción. '
        'Mencionar la palabra "categoría" o "subcategoría" antes del nombre '
        '(p. ej. "categoría Comida, subcategoría restaurante") '
        'ayuda a la IA a registrar la transacción correctamente.',
    targetKey: TutorialKeys.voiceBtnKey,
    icon: Icons.mic_outlined,
    spotlightPadding: 12,
    spotlightRadius: 28,
    // SpeedDial open animation takes 300 ms; wait for it to finish.
    measureDelay: Duration(milliseconds: 380),
  ),

  // ── 2 · Manual ────────────────────────────────────────────────────────────
  TutorialStep(
    title: '✏️ Añadir manualmente',
    body:
        'Rellena el formulario con todos los detalles: tipo (gasto/ingreso), '
        'categoría, importe, descripción, fecha e incluso recurrencia.',
    targetKey: TutorialKeys.manualBtnKey,
    icon: Icons.edit_outlined,
    spotlightPadding: 12,
    spotlightRadius: 28,
    measureDelay: Duration(milliseconds: 380),
  ),

  // ── 3 · Camera ────────────────────────────────────────────────────────────
  TutorialStep(
    title: '📷 Añadir con foto',
    body:
        'Fotografía un ticket o recibo y la IA lo interpretará '
        'automáticamente y lo añadirá como transacción lista para guardar.',
    targetKey: TutorialKeys.cameraBtnKey,
    icon: Icons.camera_alt_outlined,
    spotlightPadding: 12,
    spotlightRadius: 28,
    measureDelay: Duration(milliseconds: 380),
  ),

  // ── 4 · Balance card ──────────────────────────────────────────────────────
  TutorialStep(
    title: 'Tu resumen financiero',
    body:
        'Aquí ves el balance total, los ingresos y los gastos del período '
        'seleccionado. La barra de color muestra la proporción entre ambos.',
    targetKey: TutorialKeys.balanceCardKey,
    icon: Icons.account_balance_wallet_outlined,
    spotlightPadding: 10,
    spotlightRadius: 24,
  ),

  // ── 5 · Charts button ─────────────────────────────────────────────────────
  TutorialStep(
    title: 'Gráficos de distribución',
    body:
        'Toca para ver gráficos de tarta y barras que muestran cómo se '
        'distribuyen tus ingresos y gastos por categoría.',
    targetKey: TutorialKeys.chartsBtnKey,
    icon: Icons.pie_chart_outline_rounded,
    spotlightPadding: 8,
    spotlightRadius: 14,
  ),

  // ── 6 · See-all button ────────────────────────────────────────────────────
  TutorialStep(
    title: 'Historial de transacciones',
    body:
        'Pulsa "Ver todo" para acceder al historial completo con filtros, '
        'búsqueda y orden personalizado.',
    targetKey: TutorialKeys.seeAllBtnKey,
    icon: Icons.list_alt_outlined,
    spotlightPadding: 8,
    spotlightRadius: 100,
  ),

  // ── 7 · Drawer button ─────────────────────────────────────────────────────
  TutorialStep(
    title: 'Menú de configuración',
    body:
        'Desde el menú lateral puedes cambiar el idioma, la moneda, '
        'el tema visual y gestionar tu suscripción PRO.',
    targetKey: TutorialKeys.drawerBtnKey,
    icon: Icons.menu_rounded,
    spotlightPadding: 6,
    spotlightRadius: 12,
  ),
];
