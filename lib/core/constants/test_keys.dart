import 'package:flutter/widgets.dart';

/// Keys estables que usan los flujos de `integration_test/` para localizar
/// widgets sin depender de textos localizados. Si refactorizas una de estas
/// pantallas, mantén la key sobre el widget equivalente.
class TestKeys {
  TestKeys._();

  // Login
  static const loginEmailField = ValueKey('login-email');
  static const loginPasswordField = ValueKey('login-password');
  static const loginSubmitButton = ValueKey('login-submit');

  /// Tecla ✓ (guardar) del keypad numérico de añadir/editar transacción.
  static const keypadSubmit = ValueKey('keypad-submit');

  /// Enlace a /budgets desde la sección de presupuestos del dashboard
  /// (tanto el CTA vacío como el botón "Gestionar" llevan esta key; nunca
  /// coexisten en pantalla).
  static const budgetsSectionLink = ValueKey('budgets-section-link');
}
