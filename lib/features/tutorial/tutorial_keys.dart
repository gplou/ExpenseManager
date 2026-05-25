import 'package:flutter/widgets.dart';

/// Central registry of [GlobalKey]s used by the interactive tutorial
/// to locate widgets on screen and draw the spotlight overlay.
class TutorialKeys {
  TutorialKeys._();

  /// Main + FAB button.
  static final fabKey = GlobalKey(debugLabel: 'tutorial_fab');

  /// Balance / income / expense summary card.
  static final balanceCardKey = GlobalKey(debugLabel: 'tutorial_balance_card');

  /// "Ver gráficos" outlined button.
  static final chartsBtnKey = GlobalKey(debugLabel: 'tutorial_charts_btn');

  /// "Ver todo" transactions button.
  static final seeAllBtnKey = GlobalKey(debugLabel: 'tutorial_see_all_btn');

  /// Hamburger / drawer icon button.
  static final drawerBtnKey = GlobalKey(debugLabel: 'tutorial_drawer_btn');

  /// ✨  AI chat icon button (only present for PRO users).
  static final chatBtnKey = GlobalKey(debugLabel: 'tutorial_chat_btn');
}
