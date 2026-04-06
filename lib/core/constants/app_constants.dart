/// Widget action identifiers used across home-screen widgets, deep links,
/// and the dashboard FAB. Centralised here to avoid string duplication.
abstract class WidgetActions {
  static const voice = 'voice';
  static const add = 'add';
  static const chat = 'chat';
  static const photo = 'photo';

  /// All valid action values, used for validation.
  static const all = {voice, add, chat, photo};
}
