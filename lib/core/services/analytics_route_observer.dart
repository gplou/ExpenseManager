import 'package:flutter/widgets.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

/// Sends a PostHog `$screen` event on every push/replace navigation.
class AnalyticsRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _sendScreen(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) _sendScreen(newRoute);
  }

  void _sendScreen(Route<dynamic> route) {
    final name = route.settings.name;
    if (name != null && name.isNotEmpty) {
      Posthog().screen(screenName: name);
    }
  }
}
