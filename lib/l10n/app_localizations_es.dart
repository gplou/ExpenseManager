// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String greeting(String name) {
    return 'Hola, $name 👋';
  }

  @override
  String get defaultUser => 'usuario';

  @override
  String get balance => 'Balance';

  @override
  String get income => 'Ingresos';

  @override
  String get expenses => 'Gastos';

  @override
  String get recent => 'Recientes';

  @override
  String get seeAll => 'Ver todo';

  @override
  String get noTransactionsPeriod => 'Sin transacciones este período';

  @override
  String get customRange => 'Rango personalizado';

  @override
  String get periodWeek => 'Semana';

  @override
  String get periodMonth => 'Mes';

  @override
  String get periodYear => 'Año';

  @override
  String get typeIncome => 'Ingreso';

  @override
  String get typeExpense => 'Gasto';

  @override
  String get newTransaction => 'Nueva transacción';

  @override
  String get editTransaction => 'Editar transacción';

  @override
  String get amount => 'Importe';

  @override
  String get amountHint => '0,00';

  @override
  String get category => 'Categoría';

  @override
  String get descriptionOptional => 'Descripción (opcional)';

  @override
  String get descriptionHint => 'Añade una nota...';

  @override
  String get date => 'Fecha';

  @override
  String get recurringTransaction => 'Transacción recurrente';

  @override
  String get weekly => 'Semanal';

  @override
  String get monthly => 'Mensual';

  @override
  String get saveChanges => 'Guardar cambios';

  @override
  String get saveExpense => 'Guardar gasto';

  @override
  String get saveIncome => 'Guardar ingreso';

  @override
  String nextRepetition(String date, String frequency) {
    return 'La próxima repetición será el $date y cada $frequency a partir de entonces.';
  }

  @override
  String get frequencyWeek => 'semana';

  @override
  String get frequencyMonth => 'mes';

  @override
  String get invalidAmount => 'Ingresa un importe válido';

  @override
  String get selectCategory => 'Selecciona una categoría';

  @override
  String get selectFrequency => 'Selecciona la frecuencia de repetición';

  @override
  String get errorSaving => 'Error al guardar';

  @override
  String get errorUpdating => 'Error al actualizar';

  @override
  String get delete => 'Eliminar';

  @override
  String get deleteTransactionConfirm => '¿Eliminar esta transacción?';

  @override
  String get deleteRecurringTransactionConfirm =>
      '¿Eliminar esta transacción recurrente? Se cancelarán todos los cobros futuros.';

  @override
  String get deleteRecurringExpenseConfirm =>
      '¿Eliminar este gasto recurrente? Este gasto o ingreso no se agregará más veces en el futuro.';

  @override
  String get deleteRecurringIncomeConfirm =>
      '¿Eliminar este ingreso recurrente? Este gasto o ingreso no se agregará más veces en el futuro.';

  @override
  String get cancel => 'Cancelar';

  @override
  String get history => 'Historial';

  @override
  String get errorLoading => 'Error al cargar';

  @override
  String get retry => 'Reintentar';

  @override
  String get noTransactions => 'Sin transacciones';

  @override
  String get today => 'HOY';

  @override
  String get yesterday => 'AYER';

  @override
  String get expenseDistribution => 'Distribución de Gastos';

  @override
  String get incomeDistribution => 'Distribución de Ingresos';

  @override
  String get noDataPeriod => 'Sin datos en este período';

  @override
  String get userSettings => 'Ajustes de usuario';

  @override
  String get username => 'Nombre de usuario';

  @override
  String get noName => 'Sin nombre';

  @override
  String get email => 'Email';

  @override
  String get changePassword => 'Cambiar contraseña';

  @override
  String get appSettings => 'Ajustes de la app';

  @override
  String get darkMode => 'Modo oscuro';

  @override
  String get language => 'Idioma';

  @override
  String get logout => 'Cerrar sesión';

  @override
  String changePasswordContent(String email) {
    return 'Te enviaremos un enlace de cambio de contraseña a:\n\n$email';
  }

  @override
  String get send => 'Enviar';

  @override
  String get checkEmailPassword => 'Revisa tu email para cambiar la contraseña';

  @override
  String get errorSendingEmail =>
      'No se pudo enviar el email. Intenta de nuevo.';

  @override
  String get editName => 'Editar nombre';

  @override
  String get fullName => 'Nombre completo';

  @override
  String get save => 'Guardar';

  @override
  String get errorSavingName => 'No se pudo guardar. Intenta de nuevo.';

  @override
  String get displayUser => 'Usuario';

  @override
  String get welcome => 'Bienvenido';

  @override
  String get loginSubtitle => 'Inicia sesión para continuar';

  @override
  String get emailLabel => 'Email';

  @override
  String get enterEmail => 'Ingresa tu email';

  @override
  String get invalidEmail => 'Email inválido';

  @override
  String get passwordLabel => 'Contraseña';

  @override
  String get enterPassword => 'Ingresa tu contraseña';

  @override
  String get forgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get signIn => 'Iniciar sesión';

  @override
  String get orContinueWith => 'O continúa con';

  @override
  String get continueWithGoogle => 'Continuar con Google';

  @override
  String get continueWithApple => 'Continuar con Apple';

  @override
  String get noAccount => '¿No tienes cuenta? ';

  @override
  String get signUp => 'Regístrate';

  @override
  String get createAccount => 'Crear cuenta';

  @override
  String get registerSubtitle => 'Completa los datos para registrarte';

  @override
  String get nameLabel => 'Nombre';

  @override
  String get enterName => 'Ingresa tu nombre';

  @override
  String get passwordMinChars => 'Mínimo 8 caracteres';

  @override
  String get enterPasswordRequired => 'Ingresa una contraseña';

  @override
  String get passwordTooShort =>
      'La contraseña debe tener al menos 8 caracteres';

  @override
  String get accountCreated =>
      '¡Cuenta creada! Revisa tu email para verificarla.';

  @override
  String get relToday => 'Hoy';

  @override
  String get relTomorrow => 'Mañana';

  @override
  String get relOverdue => 'Vencida';

  @override
  String get categorySalary => 'Salario';

  @override
  String get categoryFreelance => 'Freelance';

  @override
  String get categoryInvestment => 'Inversión';

  @override
  String get categoryGift => 'Regalo';

  @override
  String get categoryFood => 'Comida';

  @override
  String get categoryTransport => 'Transporte';

  @override
  String get categoryHousing => 'Vivienda';

  @override
  String get categoryLeisure => 'Ocio';

  @override
  String get categoryHealth => 'Salud';

  @override
  String get categoryEducation => 'Educación';

  @override
  String get categoryClothing => 'Ropa';

  @override
  String get categoryTechnology => 'Tecnología';

  @override
  String get categoryOther => 'Otros';

  @override
  String get newCategory => 'Nueva categoría';

  @override
  String get categoryName => 'Nombre de la categoría';

  @override
  String get chooseIcon => 'Elige un icono';

  @override
  String get exportExcel => 'Exportar a Excel';

  @override
  String get exportSuccess => 'Guardado en Descargas';

  @override
  String get exportError => 'Error al exportar el archivo';

  @override
  String get exportColumnDate => 'Fecha';

  @override
  String get exportColumnType => 'Tipo';

  @override
  String get exportColumnCategory => 'Categoría';

  @override
  String get exportColumnDescription => 'Descripción';

  @override
  String get exportColumnAmount => 'Importe';
}
