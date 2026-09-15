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

  // ── Controles localizados por icono ───────────────────────────────────────
  // El harness (`tool/screenshots/`) y los flujos E2E solían buscar estos
  // botones con `find.byIcon(Icons.*)`. La identidad del icono es un contrato
  // equivocado para un finder: la migración a Phosphor los dejó apuntando a
  // glifos inexistentes sin que nada fallara en compilación. Al refactorizar
  // estas pantallas, mantén la key sobre el widget equivalente.

  /// Selector de rango personalizado en la tira de periodos del dashboard.
  static const dashboardDateRangeButton = ValueKey('dashboard-date-range');

  /// Conmutador tarta/barras de la pantalla de gráficos.
  static const chartsModePie = ValueKey('charts-mode-pie');
  static const chartsModeBar = ValueKey('charts-mode-bar');

  /// Desplegable de periodo de la pantalla de gráficos.
  static const chartsPeriodButton = ValueKey('charts-period');

  /// Cabecera del historial: filtro por categoría, búsqueda y salir de ella.
  static const transactionsFilterButton = ValueKey('transactions-filter');
  static const transactionsSearchButton = ValueKey('transactions-search');
  static const transactionsSearchBack = ValueKey('transactions-search-back');

  /// Alta/edición de transacción: pastilla de nota y borrado.
  static const transactionNotePill = ValueKey('transaction-note-pill');
  static const transactionDeleteButton = ValueKey('transaction-delete');

  /// Borrar un presupuesto desde la lista.
  static const budgetDeleteButton = ValueKey('budget-delete');
}
