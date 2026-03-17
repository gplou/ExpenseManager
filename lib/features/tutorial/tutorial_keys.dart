import 'package:flutter/widgets.dart';

/// Central registry of [GlobalKey]s used by the interactive tutorial
/// to locate widgets on screen and draw the spotlight overlay.
class TutorialKeys {
  TutorialKeys._();

  // ── Speed dial ─────────────────────────────────────────────────────────────
  /// Main + FAB button.
  static final fabKey = GlobalKey(debugLabel: 'tutorial_fab');

  /// 🎤  Voice mini-button (only visible when dial is open).
  static final voiceBtnKey = GlobalKey(debugLabel: 'tutorial_voice_btn');

  /// ✏️  Manual mini-button (only visible when dial is open).
  static final manualBtnKey = GlobalKey(debugLabel: 'tutorial_manual_btn');

  /// 📷  Camera mini-button (only visible when dial is open).
  static final cameraBtnKey = GlobalKey(debugLabel: 'tutorial_camera_btn');

  // ── Dashboard summary ──────────────────────────────────────────────────────
  /// Balance / income / expense summary card.
  static final balanceCardKey = GlobalKey(debugLabel: 'tutorial_balance_card');

  /// "Ver gráficos" outlined button.
  static final chartsBtnKey = GlobalKey(debugLabel: 'tutorial_charts_btn');

  /// "Ver todo" transactions button.
  static final seeAllBtnKey = GlobalKey(debugLabel: 'tutorial_see_all_btn');

  // ── App bar ────────────────────────────────────────────────────────────────
  /// Hamburger / drawer icon button.
  static final drawerBtnKey = GlobalKey(debugLabel: 'tutorial_drawer_btn');

  /// ✨  AI chat icon button (only present for PRO users).
  static final chatBtnKey = GlobalKey(debugLabel: 'tutorial_chat_btn');
}
