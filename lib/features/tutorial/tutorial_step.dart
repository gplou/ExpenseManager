import 'package:flutter/material.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

import 'tutorial_keys.dart';

class TutorialStep {
  const TutorialStep({
    required this.title,
    required this.body,
    required this.targetKey,
    this.icon,
    this.spotlightPadding = 14.0,
    this.spotlightRadius = 18.0,
    this.skipIfKeyMissing = false,
  });

  final String title;
  final String body;
  final GlobalKey targetKey;
  final IconData? icon;
  final double spotlightPadding;
  final double spotlightRadius;

  /// When true, this step is skipped if [targetKey] has no context
  /// (i.e. the widget is not rendered — e.g. PRO-only chat icon).
  final bool skipIfKeyMissing;
}

List<TutorialStep> buildTutorialSteps(AppLocalizations l10n) => [
  // 0 · Add transaction (FAB) — covers manual, voice, photo in one card
  TutorialStep(
    title: l10n.tutorialAddTitle,
    body: l10n.tutorialAddBody,
    targetKey: TutorialKeys.fabKey,
    icon: Icons.add_circle_outline_rounded,
    spotlightPadding: 10,
    spotlightRadius: 32,
  ),

  // 1 · Balance card
  TutorialStep(
    title: l10n.tutorialBalanceTitle,
    body: l10n.tutorialBalanceBody,
    targetKey: TutorialKeys.balanceCardKey,
    icon: Icons.account_balance_wallet_outlined,
    spotlightPadding: 10,
    spotlightRadius: 24,
  ),

  // 2 · Charts
  TutorialStep(
    title: l10n.tutorialChartsStepTitle,
    body: l10n.tutorialChartsStepBody,
    targetKey: TutorialKeys.chartsBtnKey,
    icon: Icons.pie_chart_outline_rounded,
    spotlightPadding: 8,
    spotlightRadius: 14,
  ),

  // 3 · Transaction history
  TutorialStep(
    title: l10n.tutorialHistoryStepTitle,
    body: l10n.tutorialHistoryStepBody,
    targetKey: TutorialKeys.seeAllBtnKey,
    icon: Icons.list_alt_outlined,
    spotlightPadding: 8,
    spotlightRadius: 100,
  ),

  // 4 · AI Chat (PRO only — auto-skipped for free users)
  TutorialStep(
    title: l10n.tutorialChatStepTitle,
    body: l10n.tutorialChatStepBody,
    targetKey: TutorialKeys.chatBtnKey,
    icon: Icons.auto_awesome,
    spotlightPadding: 6,
    spotlightRadius: 12,
    skipIfKeyMissing: true,
  ),

  // 5 · Drawer (settings)
  TutorialStep(
    title: l10n.tutorialDrawerTitle,
    body: l10n.tutorialDrawerBody,
    targetKey: TutorialKeys.drawerBtnKey,
    icon: Icons.menu_rounded,
    spotlightPadding: 6,
    spotlightRadius: 12,
  ),
];

/// Total number of tutorial steps. Must match the list length in [buildTutorialSteps].
const int kTutorialStepCount = 6;
