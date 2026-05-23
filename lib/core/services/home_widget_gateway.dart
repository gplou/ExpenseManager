import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

/// Thin abstraction over the static `HomeWidget.*` API so screens that
/// listen to home-screen widget callbacks can be tested without a device.
abstract interface class HomeWidgetGateway {
  /// Stream of URIs emitted when the user taps the home-screen widget.
  Stream<Uri?> get widgetClicked;
}

class HomeWidgetGatewayImpl implements HomeWidgetGateway {
  const HomeWidgetGatewayImpl();

  @override
  Stream<Uri?> get widgetClicked => HomeWidget.widgetClicked;
}

final homeWidgetGatewayProvider = Provider<HomeWidgetGateway>((ref) {
  return const HomeWidgetGatewayImpl();
});
