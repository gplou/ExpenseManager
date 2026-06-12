import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

/// Thin abstraction over the static `HomeWidget.*` API so screens that
/// listen to home-screen widget callbacks can be tested without a device.
abstract interface class HomeWidgetGateway {
  /// Stream of URIs emitted when the user taps the home-screen widget.
  Stream<Uri?> get widgetClicked;

  /// Persiste un valor (string ya formateado) legible por el widget nativo.
  /// `null` elimina la clave (el widget oculta el dato).
  Future<void> saveWidgetData(String key, String? value);

  /// Pide al sistema que repinte los widgets de la app.
  Future<void> updateWidget();
}

class HomeWidgetGatewayImpl implements HomeWidgetGateway {
  const HomeWidgetGatewayImpl();

  @override
  Stream<Uri?> get widgetClicked => HomeWidget.widgetClicked;

  @override
  Future<void> saveWidgetData(String key, String? value) =>
      HomeWidget.saveWidgetData<String?>(key, value);

  @override
  Future<void> updateWidget() async {
    await HomeWidget.updateWidget(
      androidName: 'QuadWidgetProvider',
      // Kind del target WidgetKit (A7); inocuo mientras no exista.
      iOSName: 'ExpenseManagerWidget',
    );
  }
}

final homeWidgetGatewayProvider = Provider<HomeWidgetGateway>((ref) {
  return const HomeWidgetGatewayImpl();
});
