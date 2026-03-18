import 'package:flutter/material.dart';
import 'package:productivity_app/l10n/app_localizations.dart';

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
    this.skipIfKeyMissing = false,
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

  /// When true, this step is automatically skipped if [targetKey] has no
  /// context (i.e. the widget is not rendered). Useful for steps targeting
  /// features that are only available to certain user types (e.g. PRO).
  final bool skipIfKeyMissing;
}

/// Total number of tutorial steps. Must match the list length in [buildTutorialSteps].
const int kTutorialStepCount = 9;

/// The ordered list of all tutorial steps shown to the user.
List<TutorialStep> buildTutorialSteps(AppLocalizations l10n) => [
  // ── 0 · Main FAB ──────────────────────────────────────────────────────────
  TutorialStep(
    title: l10n.tutorialAddTitle,
    body: l10n.tutorialAddBody,
    targetKey: TutorialKeys.fabKey,
    icon: Icons.add_circle_outline_rounded,
    spotlightPadding: 10,
    spotlightRadius: 32,
    measureDelay: const Duration(milliseconds: 300),
  ),

  // ── 1 · Voice ─────────────────────────────────────────────────────────────
  TutorialStep(
    title: l10n.tutorialVoiceStepTitle,
    body: l10n.tutorialVoiceStepBody,
    targetKey: TutorialKeys.voiceBtnKey,
    icon: Icons.mic_outlined,
    spotlightPadding: 12,
    spotlightRadius: 28,
    // SpeedDial open animation takes 300 ms; wait for it to finish.
    measureDelay: const Duration(milliseconds: 380),
  ),

  // ── 2 · Manual ────────────────────────────────────────────────────────────
  TutorialStep(
    title: l10n.tutorialManualStepTitle,
    body: l10n.tutorialManualStepBody,
    targetKey: TutorialKeys.manualBtnKey,
    icon: Icons.edit_outlined,
    spotlightPadding: 12,
    spotlightRadius: 28,
    measureDelay: const Duration(milliseconds: 380),
  ),

  // ── 3 · Camera ────────────────────────────────────────────────────────────
  TutorialStep(
    title: l10n.tutorialCameraStepTitle,
    body: l10n.tutorialCameraStepBody,
    targetKey: TutorialKeys.cameraBtnKey,
    icon: Icons.camera_alt_outlined,
    spotlightPadding: 12,
    spotlightRadius: 28,
    measureDelay: const Duration(milliseconds: 380),
  ),

  // ── 4 · Balance card ──────────────────────────────────────────────────────
  TutorialStep(
    title: l10n.tutorialBalanceTitle,
    body: l10n.tutorialBalanceBody,
    targetKey: TutorialKeys.balanceCardKey,
    icon: Icons.account_balance_wallet_outlined,
    spotlightPadding: 10,
    spotlightRadius: 24,
  ),

  // ── 5 · Charts button ─────────────────────────────────────────────────────
  TutorialStep(
    title: l10n.tutorialChartsStepTitle,
    body: l10n.tutorialChartsStepBody,
    targetKey: TutorialKeys.chartsBtnKey,
    icon: Icons.pie_chart_outline_rounded,
    spotlightPadding: 8,
    spotlightRadius: 14,
  ),

  // ── 6 · See-all button ────────────────────────────────────────────────────
  TutorialStep(
    title: l10n.tutorialHistoryStepTitle,
    body: l10n.tutorialHistoryStepBody,
    targetKey: TutorialKeys.seeAllBtnKey,
    icon: Icons.list_alt_outlined,
    spotlightPadding: 8,
    spotlightRadius: 100,
  ),

  // ── 7 · AI Chat (PRO) ─────────────────────────────────────────────────────
  TutorialStep(
    title: l10n.tutorialChatStepTitle,
    body: l10n.tutorialChatStepBody,
    targetKey: TutorialKeys.chatBtnKey,
    icon: Icons.auto_awesome,
    spotlightPadding: 6,
    spotlightRadius: 12,
    skipIfKeyMissing: true,
  ),

  // ── 8 · Drawer button ─────────────────────────────────────────────────────
  TutorialStep(
    title: l10n.tutorialDrawerTitle,
    body: l10n.tutorialDrawerBody,
    targetKey: TutorialKeys.drawerBtnKey,
    icon: Icons.menu_rounded,
    spotlightPadding: 6,
    spotlightRadius: 12,
  ),
];
