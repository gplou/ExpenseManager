import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr')
  ];

  /// No description provided for @greeting.
  ///
  /// In es, this message translates to:
  /// **'Hola, {name} 👋'**
  String greeting(String name);

  /// No description provided for @defaultUser.
  ///
  /// In es, this message translates to:
  /// **'usuario'**
  String get defaultUser;

  /// No description provided for @balance.
  ///
  /// In es, this message translates to:
  /// **'Balance'**
  String get balance;

  /// No description provided for @income.
  ///
  /// In es, this message translates to:
  /// **'Ingresos'**
  String get income;

  /// No description provided for @expenses.
  ///
  /// In es, this message translates to:
  /// **'Gastos'**
  String get expenses;

  /// No description provided for @recent.
  ///
  /// In es, this message translates to:
  /// **'Recientes'**
  String get recent;

  /// No description provided for @seeAll.
  ///
  /// In es, this message translates to:
  /// **'Ver todo'**
  String get seeAll;

  /// No description provided for @noTransactionsPeriod.
  ///
  /// In es, this message translates to:
  /// **'Sin transacciones este período'**
  String get noTransactionsPeriod;

  /// No description provided for @customRange.
  ///
  /// In es, this message translates to:
  /// **'Rango personalizado'**
  String get customRange;

  /// No description provided for @periodWeek.
  ///
  /// In es, this message translates to:
  /// **'Semana'**
  String get periodWeek;

  /// No description provided for @periodMonth.
  ///
  /// In es, this message translates to:
  /// **'Mes'**
  String get periodMonth;

  /// No description provided for @periodYear.
  ///
  /// In es, this message translates to:
  /// **'Año'**
  String get periodYear;

  /// No description provided for @typeIncome.
  ///
  /// In es, this message translates to:
  /// **'Ingreso'**
  String get typeIncome;

  /// No description provided for @typeExpense.
  ///
  /// In es, this message translates to:
  /// **'Gasto'**
  String get typeExpense;

  /// No description provided for @newTransaction.
  ///
  /// In es, this message translates to:
  /// **'Nueva transacción'**
  String get newTransaction;

  /// No description provided for @editTransaction.
  ///
  /// In es, this message translates to:
  /// **'Editar transacción'**
  String get editTransaction;

  /// No description provided for @amount.
  ///
  /// In es, this message translates to:
  /// **'Importe'**
  String get amount;

  /// No description provided for @amountHint.
  ///
  /// In es, this message translates to:
  /// **'0,00'**
  String get amountHint;

  /// No description provided for @category.
  ///
  /// In es, this message translates to:
  /// **'Categoría'**
  String get category;

  /// No description provided for @descriptionOptional.
  ///
  /// In es, this message translates to:
  /// **'Descripción (opcional)'**
  String get descriptionOptional;

  /// No description provided for @descriptionHint.
  ///
  /// In es, this message translates to:
  /// **'Añade una nota...'**
  String get descriptionHint;

  /// No description provided for @date.
  ///
  /// In es, this message translates to:
  /// **'Fecha'**
  String get date;

  /// No description provided for @recurringTransaction.
  ///
  /// In es, this message translates to:
  /// **'Transacción recurrente'**
  String get recurringTransaction;

  /// No description provided for @weekly.
  ///
  /// In es, this message translates to:
  /// **'Semanal'**
  String get weekly;

  /// No description provided for @monthly.
  ///
  /// In es, this message translates to:
  /// **'Mensual'**
  String get monthly;

  /// No description provided for @yearly.
  ///
  /// In es, this message translates to:
  /// **'Anual'**
  String get yearly;

  /// No description provided for @saveChanges.
  ///
  /// In es, this message translates to:
  /// **'Guardar cambios'**
  String get saveChanges;

  /// No description provided for @saveExpense.
  ///
  /// In es, this message translates to:
  /// **'Guardar gasto'**
  String get saveExpense;

  /// No description provided for @saveIncome.
  ///
  /// In es, this message translates to:
  /// **'Guardar ingreso'**
  String get saveIncome;

  /// No description provided for @nextRepetition.
  ///
  /// In es, this message translates to:
  /// **'La próxima repetición será el {date} y cada {frequency} a partir de entonces.'**
  String nextRepetition(String date, String frequency);

  /// No description provided for @frequencyWeek.
  ///
  /// In es, this message translates to:
  /// **'semana'**
  String get frequencyWeek;

  /// No description provided for @frequencyMonth.
  ///
  /// In es, this message translates to:
  /// **'mes'**
  String get frequencyMonth;

  /// No description provided for @frequencyYear.
  ///
  /// In es, this message translates to:
  /// **'año'**
  String get frequencyYear;

  /// No description provided for @invalidAmount.
  ///
  /// In es, this message translates to:
  /// **'Ingresa un importe válido'**
  String get invalidAmount;

  /// No description provided for @selectCategory.
  ///
  /// In es, this message translates to:
  /// **'Selecciona una categoría'**
  String get selectCategory;

  /// No description provided for @selectFrequency.
  ///
  /// In es, this message translates to:
  /// **'Selecciona la frecuencia de repetición'**
  String get selectFrequency;

  /// No description provided for @errorSaving.
  ///
  /// In es, this message translates to:
  /// **'Error al guardar'**
  String get errorSaving;

  /// No description provided for @errorUpdating.
  ///
  /// In es, this message translates to:
  /// **'Error al actualizar'**
  String get errorUpdating;

  /// No description provided for @delete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get delete;

  /// No description provided for @deleteTransactionConfirm.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar esta transacción?'**
  String get deleteTransactionConfirm;

  /// No description provided for @deleteRecurringTransactionConfirm.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar esta transacción recurrente? Se cancelarán todos los cobros futuros.'**
  String get deleteRecurringTransactionConfirm;

  /// No description provided for @deleteRecurringExpenseConfirm.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar este gasto recurrente? Este gasto o ingreso no se agregará más veces en el futuro.'**
  String get deleteRecurringExpenseConfirm;

  /// No description provided for @deleteRecurringIncomeConfirm.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar este ingreso recurrente? Este gasto o ingreso no se agregará más veces en el futuro.'**
  String get deleteRecurringIncomeConfirm;

  /// No description provided for @cancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @history.
  ///
  /// In es, this message translates to:
  /// **'Historial'**
  String get history;

  /// No description provided for @errorLoading.
  ///
  /// In es, this message translates to:
  /// **'Error al cargar'**
  String get errorLoading;

  /// No description provided for @retry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get retry;

  /// No description provided for @noTransactions.
  ///
  /// In es, this message translates to:
  /// **'Sin transacciones'**
  String get noTransactions;

  /// No description provided for @today.
  ///
  /// In es, this message translates to:
  /// **'HOY'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In es, this message translates to:
  /// **'AYER'**
  String get yesterday;

  /// No description provided for @expenseDistribution.
  ///
  /// In es, this message translates to:
  /// **'Distribución de Gastos'**
  String get expenseDistribution;

  /// No description provided for @incomeDistribution.
  ///
  /// In es, this message translates to:
  /// **'Distribución de Ingresos'**
  String get incomeDistribution;

  /// No description provided for @noDataPeriod.
  ///
  /// In es, this message translates to:
  /// **'Sin datos en este período'**
  String get noDataPeriod;

  /// No description provided for @userSettings.
  ///
  /// In es, this message translates to:
  /// **'Ajustes de usuario'**
  String get userSettings;

  /// No description provided for @username.
  ///
  /// In es, this message translates to:
  /// **'Nombre de usuario'**
  String get username;

  /// No description provided for @noName.
  ///
  /// In es, this message translates to:
  /// **'Sin nombre'**
  String get noName;

  /// No description provided for @email.
  ///
  /// In es, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @changePassword.
  ///
  /// In es, this message translates to:
  /// **'Cambiar contraseña'**
  String get changePassword;

  /// No description provided for @appSettings.
  ///
  /// In es, this message translates to:
  /// **'Ajustes de la app'**
  String get appSettings;

  /// No description provided for @darkMode.
  ///
  /// In es, this message translates to:
  /// **'Modo oscuro'**
  String get darkMode;

  /// No description provided for @language.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get language;

  /// No description provided for @logout.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get logout;

  /// No description provided for @changePasswordContent.
  ///
  /// In es, this message translates to:
  /// **'Te enviaremos un enlace de cambio de contraseña a:\n\n{email}'**
  String changePasswordContent(String email);

  /// No description provided for @send.
  ///
  /// In es, this message translates to:
  /// **'Enviar'**
  String get send;

  /// No description provided for @checkEmailPassword.
  ///
  /// In es, this message translates to:
  /// **'Revisa tu email para cambiar la contraseña'**
  String get checkEmailPassword;

  /// No description provided for @errorSendingEmail.
  ///
  /// In es, this message translates to:
  /// **'No se pudo enviar el email. Intenta de nuevo.'**
  String get errorSendingEmail;

  /// No description provided for @editName.
  ///
  /// In es, this message translates to:
  /// **'Editar nombre'**
  String get editName;

  /// No description provided for @fullName.
  ///
  /// In es, this message translates to:
  /// **'Nombre completo'**
  String get fullName;

  /// No description provided for @save.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get save;

  /// No description provided for @errorSavingName.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar. Intenta de nuevo.'**
  String get errorSavingName;

  /// No description provided for @displayUser.
  ///
  /// In es, this message translates to:
  /// **'Usuario'**
  String get displayUser;

  /// No description provided for @welcome.
  ///
  /// In es, this message translates to:
  /// **'Bienvenido'**
  String get welcome;

  /// No description provided for @loginSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Inicia sesión para continuar'**
  String get loginSubtitle;

  /// No description provided for @emailLabel.
  ///
  /// In es, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @enterEmail.
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu email'**
  String get enterEmail;

  /// No description provided for @invalidEmail.
  ///
  /// In es, this message translates to:
  /// **'Email inválido'**
  String get invalidEmail;

  /// No description provided for @passwordLabel.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get passwordLabel;

  /// No description provided for @enterPassword.
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu contraseña'**
  String get enterPassword;

  /// No description provided for @forgotPassword.
  ///
  /// In es, this message translates to:
  /// **'¿Olvidaste tu contraseña?'**
  String get forgotPassword;

  /// No description provided for @signIn.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión'**
  String get signIn;

  /// No description provided for @orContinueWith.
  ///
  /// In es, this message translates to:
  /// **'O continúa con'**
  String get orContinueWith;

  /// No description provided for @continueWithGoogle.
  ///
  /// In es, this message translates to:
  /// **'Continuar con Google'**
  String get continueWithGoogle;

  /// No description provided for @continueWithApple.
  ///
  /// In es, this message translates to:
  /// **'Continuar con Apple'**
  String get continueWithApple;

  /// No description provided for @noAccount.
  ///
  /// In es, this message translates to:
  /// **'¿No tienes cuenta? '**
  String get noAccount;

  /// No description provided for @signUp.
  ///
  /// In es, this message translates to:
  /// **'Regístrate'**
  String get signUp;

  /// No description provided for @createAccount.
  ///
  /// In es, this message translates to:
  /// **'Crear cuenta'**
  String get createAccount;

  /// No description provided for @registerSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Completa los datos para registrarte'**
  String get registerSubtitle;

  /// No description provided for @nameLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get nameLabel;

  /// No description provided for @enterName.
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu nombre'**
  String get enterName;

  /// No description provided for @passwordMinChars.
  ///
  /// In es, this message translates to:
  /// **'Mínimo 8 caracteres, una letra y un número'**
  String get passwordMinChars;

  /// No description provided for @enterPasswordRequired.
  ///
  /// In es, this message translates to:
  /// **'Ingresa una contraseña'**
  String get enterPasswordRequired;

  /// No description provided for @passwordTooShort.
  ///
  /// In es, this message translates to:
  /// **'La contraseña debe tener al menos 8 caracteres, una letra y un número'**
  String get passwordTooShort;

  /// No description provided for @accountCreated.
  ///
  /// In es, this message translates to:
  /// **'¡Cuenta creada! Revisa tu email para verificarla.'**
  String get accountCreated;

  /// No description provided for @relToday.
  ///
  /// In es, this message translates to:
  /// **'Hoy'**
  String get relToday;

  /// No description provided for @relTomorrow.
  ///
  /// In es, this message translates to:
  /// **'Mañana'**
  String get relTomorrow;

  /// No description provided for @relOverdue.
  ///
  /// In es, this message translates to:
  /// **'Vencida'**
  String get relOverdue;

  /// No description provided for @categorySalary.
  ///
  /// In es, this message translates to:
  /// **'Salario'**
  String get categorySalary;

  /// No description provided for @categoryFreelance.
  ///
  /// In es, this message translates to:
  /// **'Freelance'**
  String get categoryFreelance;

  /// No description provided for @categoryInvestment.
  ///
  /// In es, this message translates to:
  /// **'Inversión'**
  String get categoryInvestment;

  /// No description provided for @categoryGift.
  ///
  /// In es, this message translates to:
  /// **'Regalo'**
  String get categoryGift;

  /// No description provided for @categoryFood.
  ///
  /// In es, this message translates to:
  /// **'Comida'**
  String get categoryFood;

  /// No description provided for @categoryTransport.
  ///
  /// In es, this message translates to:
  /// **'Transporte'**
  String get categoryTransport;

  /// No description provided for @categoryHousing.
  ///
  /// In es, this message translates to:
  /// **'Vivienda'**
  String get categoryHousing;

  /// No description provided for @categoryLeisure.
  ///
  /// In es, this message translates to:
  /// **'Ocio'**
  String get categoryLeisure;

  /// No description provided for @categoryHealth.
  ///
  /// In es, this message translates to:
  /// **'Salud'**
  String get categoryHealth;

  /// No description provided for @categoryEducation.
  ///
  /// In es, this message translates to:
  /// **'Educación'**
  String get categoryEducation;

  /// No description provided for @categoryClothing.
  ///
  /// In es, this message translates to:
  /// **'Ropa'**
  String get categoryClothing;

  /// No description provided for @categoryTechnology.
  ///
  /// In es, this message translates to:
  /// **'Tecnología'**
  String get categoryTechnology;

  /// No description provided for @categoryOther.
  ///
  /// In es, this message translates to:
  /// **'Otros'**
  String get categoryOther;

  /// No description provided for @newCategory.
  ///
  /// In es, this message translates to:
  /// **'Nueva categoría'**
  String get newCategory;

  /// No description provided for @categoryName.
  ///
  /// In es, this message translates to:
  /// **'Nombre de la categoría'**
  String get categoryName;

  /// No description provided for @chooseIcon.
  ///
  /// In es, this message translates to:
  /// **'Elige un icono'**
  String get chooseIcon;

  /// No description provided for @exportExcel.
  ///
  /// In es, this message translates to:
  /// **'Exportar a Excel'**
  String get exportExcel;

  /// No description provided for @exportSuccess.
  ///
  /// In es, this message translates to:
  /// **'Guardado en Descargas'**
  String get exportSuccess;

  /// No description provided for @exportError.
  ///
  /// In es, this message translates to:
  /// **'Error al exportar el archivo'**
  String get exportError;

  /// No description provided for @exportColumnDate.
  ///
  /// In es, this message translates to:
  /// **'Fecha'**
  String get exportColumnDate;

  /// No description provided for @exportColumnType.
  ///
  /// In es, this message translates to:
  /// **'Tipo'**
  String get exportColumnType;

  /// No description provided for @exportColumnCategory.
  ///
  /// In es, this message translates to:
  /// **'Categoría'**
  String get exportColumnCategory;

  /// No description provided for @exportColumnDescription.
  ///
  /// In es, this message translates to:
  /// **'Descripción'**
  String get exportColumnDescription;

  /// No description provided for @exportColumnAmount.
  ///
  /// In es, this message translates to:
  /// **'Importe'**
  String get exportColumnAmount;

  /// No description provided for @proPlanTitle.
  ///
  /// In es, this message translates to:
  /// **'Plan PRO'**
  String get proPlanTitle;

  /// No description provided for @proDrawerSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Desbloquea funciones premium'**
  String get proDrawerSubtitle;

  /// No description provided for @proActiveStatus.
  ///
  /// In es, this message translates to:
  /// **'Activo · expira en {days} días'**
  String proActiveStatus(int days);

  /// No description provided for @proBenefitsTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Qué incluye PRO?'**
  String get proBenefitsTitle;

  /// No description provided for @proNoBannerAds.
  ///
  /// In es, this message translates to:
  /// **'Sin publicidad'**
  String get proNoBannerAds;

  /// No description provided for @proNoBannerAdsSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Experiencia limpia, sin interrupciones'**
  String get proNoBannerAdsSubtitle;

  /// No description provided for @proVoiceImage.
  ///
  /// In es, this message translates to:
  /// **'Voz e imagen con IA'**
  String get proVoiceImage;

  /// No description provided for @proVoiceImageSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Añade transacciones hablando o con una foto'**
  String get proVoiceImageSubtitle;

  /// No description provided for @proAIChat.
  ///
  /// In es, this message translates to:
  /// **'Chat financiero con IA'**
  String get proAIChat;

  /// No description provided for @proAIChatSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Consulta tus finanzas con un asistente inteligente'**
  String get proAIChatSubtitle;

  /// No description provided for @proPrice.
  ///
  /// In es, this message translates to:
  /// **'€4,99 / mes'**
  String get proPrice;

  /// No description provided for @proPriceSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Cancela cuando quieras'**
  String get proPriceSubtitle;

  /// No description provided for @proSubscribe.
  ///
  /// In es, this message translates to:
  /// **'Suscribirse'**
  String get proSubscribe;

  /// No description provided for @proRestorePurchases.
  ///
  /// In es, this message translates to:
  /// **'Restaurar compras'**
  String get proRestorePurchases;

  /// No description provided for @proRefreshStatus.
  ///
  /// In es, this message translates to:
  /// **'Actualizar estado'**
  String get proRefreshStatus;

  /// No description provided for @proLegalDisclaimer.
  ///
  /// In es, this message translates to:
  /// **'El pago se cargará a tu cuenta de la tienda. La suscripción se renueva automáticamente cada mes.'**
  String get proLegalDisclaimer;

  /// No description provided for @proVoiceLockedSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Función exclusiva PRO'**
  String get proVoiceLockedSubtitle;

  /// No description provided for @proHeaderActiveTitle.
  ///
  /// In es, this message translates to:
  /// **'PRO Activo'**
  String get proHeaderActiveTitle;

  /// No description provided for @proHeaderInactiveTitle.
  ///
  /// In es, this message translates to:
  /// **'Hazte PRO'**
  String get proHeaderInactiveTitle;

  /// No description provided for @proHeaderActiveSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Gracias por tu apoyo'**
  String get proHeaderActiveSubtitle;

  /// No description provided for @proHeaderInactiveSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Desbloquea todas las funciones premium'**
  String get proHeaderInactiveSubtitle;

  /// No description provided for @proActiveCardTitle.
  ///
  /// In es, this message translates to:
  /// **'Suscripción activa'**
  String get proActiveCardTitle;

  /// No description provided for @proActiveCardExpiry.
  ///
  /// In es, this message translates to:
  /// **'Expira en {days} días · {source}'**
  String proActiveCardExpiry(int days, String source);

  /// No description provided for @proSourceGooglePlay.
  ///
  /// In es, this message translates to:
  /// **'Google Play'**
  String get proSourceGooglePlay;

  /// No description provided for @proSourceAppStore.
  ///
  /// In es, this message translates to:
  /// **'App Store'**
  String get proSourceAppStore;

  /// No description provided for @proSourcePromoCode.
  ///
  /// In es, this message translates to:
  /// **'Código promo'**
  String get proSourcePromoCode;

  /// No description provided for @proProductUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Producto no disponible. Inténtalo más tarde.'**
  String get proProductUnavailable;

  /// No description provided for @proPromoBadInput.
  ///
  /// In es, this message translates to:
  /// **'Introduce un código'**
  String get proPromoBadInput;

  /// No description provided for @proPromoSuccess.
  ///
  /// In es, this message translates to:
  /// **'¡Código aplicado! Disfruta de PRO.'**
  String get proPromoSuccess;

  /// No description provided for @proPromoDiscountSuccess.
  ///
  /// In es, this message translates to:
  /// **'¡Descuento del {percentage}% aplicado! Completa tu compra para activar PRO.'**
  String proPromoDiscountSuccess(int percentage);

  /// No description provided for @proDiscountBanner.
  ///
  /// In es, this message translates to:
  /// **'Descuento {percentage}% aplicado — {bonusDays} días extra al suscribirte'**
  String proDiscountBanner(int percentage, int bonusDays);

  /// No description provided for @proPromoUnexpectedError.
  ///
  /// In es, this message translates to:
  /// **'Error inesperado. Inténtalo de nuevo.'**
  String get proPromoUnexpectedError;

  /// No description provided for @proSourceFreeTrial.
  ///
  /// In es, this message translates to:
  /// **'Prueba gratuita'**
  String get proSourceFreeTrial;

  /// No description provided for @proFreeTrialButton.
  ///
  /// In es, this message translates to:
  /// **'Prueba gratis 3 días'**
  String get proFreeTrialButton;

  /// No description provided for @proFreeTrialActivated.
  ///
  /// In es, this message translates to:
  /// **'¡Prueba activada! Disfruta de PRO durante 3 días.'**
  String get proFreeTrialActivated;

  /// No description provided for @proFreeTrialSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Prueba todas las funciones premium sin compromiso'**
  String get proFreeTrialSubtitle;

  /// No description provided for @proCloudSync.
  ///
  /// In es, this message translates to:
  /// **'Sincronización en la nube'**
  String get proCloudSync;

  /// No description provided for @proCloudSyncSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Tus datos guardados de forma segura y accesibles en todos tus dispositivos'**
  String get proCloudSyncSubtitle;

  /// No description provided for @subcategory.
  ///
  /// In es, this message translates to:
  /// **'Subcategoría'**
  String get subcategory;

  /// No description provided for @newSubcategory.
  ///
  /// In es, this message translates to:
  /// **'Nueva subcategoría'**
  String get newSubcategory;

  /// No description provided for @subcategoryName.
  ///
  /// In es, this message translates to:
  /// **'Nombre de la subcategoría'**
  String get subcategoryName;

  /// No description provided for @exportColumnSubcategory.
  ///
  /// In es, this message translates to:
  /// **'Subcategoría'**
  String get exportColumnSubcategory;

  /// No description provided for @deleteSubcategoryConfirm.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar esta subcategoría?'**
  String get deleteSubcategoryConfirm;

  /// No description provided for @currency.
  ///
  /// In es, this message translates to:
  /// **'Moneda'**
  String get currency;

  /// No description provided for @charts.
  ///
  /// In es, this message translates to:
  /// **'Gráficos'**
  String get charts;

  /// No description provided for @viewCharts.
  ///
  /// In es, this message translates to:
  /// **'Ver gráficos'**
  String get viewCharts;

  /// No description provided for @allCategories.
  ///
  /// In es, this message translates to:
  /// **'Todas las categorías'**
  String get allCategories;

  /// No description provided for @allSubcategories.
  ///
  /// In es, this message translates to:
  /// **'Todas las subcategorías'**
  String get allSubcategories;

  /// No description provided for @noSubcategory.
  ///
  /// In es, this message translates to:
  /// **'Sin subcategoría'**
  String get noSubcategory;

  /// No description provided for @chatTitle.
  ///
  /// In es, this message translates to:
  /// **'Asesor Financiero'**
  String get chatTitle;

  /// No description provided for @chatPlaceholder.
  ///
  /// In es, this message translates to:
  /// **'Pregunta sobre tus finanzas...'**
  String get chatPlaceholder;

  /// No description provided for @chatWelcomeTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu asesor financiero con IA'**
  String get chatWelcomeTitle;

  /// No description provided for @chatWelcomeSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Pregunta sobre tus gastos, ingresos y obtén consejos personalizados'**
  String get chatWelcomeSubtitle;

  /// No description provided for @chatSuggestion1.
  ///
  /// In es, this message translates to:
  /// **'¿Cuánto gasté este mes?'**
  String get chatSuggestion1;

  /// No description provided for @chatSuggestion2.
  ///
  /// In es, this message translates to:
  /// **'¿Cuál es mi mayor gasto?'**
  String get chatSuggestion2;

  /// No description provided for @chatSuggestion3.
  ///
  /// In es, this message translates to:
  /// **'Consejos para ahorrar'**
  String get chatSuggestion3;

  /// No description provided for @chatError.
  ///
  /// In es, this message translates to:
  /// **'Error al enviar el mensaje'**
  String get chatError;

  /// No description provided for @chatRateLimit.
  ///
  /// In es, this message translates to:
  /// **'Has alcanzado el límite de mensajes. Espera un momento.'**
  String get chatRateLimit;

  /// No description provided for @chatProRequired.
  ///
  /// In es, this message translates to:
  /// **'Función exclusiva PRO'**
  String get chatProRequired;

  /// No description provided for @tutorialTitle.
  ///
  /// In es, this message translates to:
  /// **'Tutorial'**
  String get tutorialTitle;

  /// No description provided for @tutorialSkip.
  ///
  /// In es, this message translates to:
  /// **'Omitir'**
  String get tutorialSkip;

  /// No description provided for @tutorialNext.
  ///
  /// In es, this message translates to:
  /// **'Siguiente'**
  String get tutorialNext;

  /// No description provided for @tutorialStart.
  ///
  /// In es, this message translates to:
  /// **'¡Empezar!'**
  String get tutorialStart;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In es, this message translates to:
  /// **'¡Bienvenido a ExpenseManager!'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeBody.
  ///
  /// In es, this message translates to:
  /// **'Gestiona tus finanzas de forma inteligente. Vamos a mostrarte cómo sacarle el máximo partido.'**
  String get onboardingWelcomeBody;

  /// No description provided for @onboardingManualTitle.
  ///
  /// In es, this message translates to:
  /// **'Añadir manualmente'**
  String get onboardingManualTitle;

  /// No description provided for @onboardingManualBody.
  ///
  /// In es, this message translates to:
  /// **'Toca el botón + del dashboard y selecciona el lápiz. Rellena el importe, tipo, categoría, subcategoría y descripción.'**
  String get onboardingManualBody;

  /// No description provided for @onboardingPhotoTitle.
  ///
  /// In es, this message translates to:
  /// **'Añadir con foto'**
  String get onboardingPhotoTitle;

  /// No description provided for @onboardingPhotoBody.
  ///
  /// In es, this message translates to:
  /// **'Toca el botón + y selecciona la cámara. Fotografía cualquier ticket o recibo y la IA extraerá los datos automáticamente.'**
  String get onboardingPhotoBody;

  /// No description provided for @onboardingVoiceTitle.
  ///
  /// In es, this message translates to:
  /// **'Añadir con voz (PRO)'**
  String get onboardingVoiceTitle;

  /// No description provided for @onboardingVoiceBody.
  ///
  /// In es, this message translates to:
  /// **'Toca el micrófono y dicta tu transacción. Para mejores resultados, incluye siempre categoría, subcategoría, importe y descripción.'**
  String get onboardingVoiceBody;

  /// No description provided for @onboardingVoiceImportant.
  ///
  /// In es, this message translates to:
  /// **'¡Importante! Incluye estos datos:'**
  String get onboardingVoiceImportant;

  /// No description provided for @onboardingVoiceBulletAmount.
  ///
  /// In es, this message translates to:
  /// **'Importe: «25 euros»'**
  String get onboardingVoiceBulletAmount;

  /// No description provided for @onboardingVoiceBulletCategory.
  ///
  /// In es, this message translates to:
  /// **'Categoría: «comida»'**
  String get onboardingVoiceBulletCategory;

  /// No description provided for @onboardingVoiceBulletSubcategory.
  ///
  /// In es, this message translates to:
  /// **'Subcategoría: «restaurante»'**
  String get onboardingVoiceBulletSubcategory;

  /// No description provided for @onboardingVoiceBulletDescription.
  ///
  /// In es, this message translates to:
  /// **'Descripción: «almuerzo con clientes»'**
  String get onboardingVoiceBulletDescription;

  /// No description provided for @onboardingVoiceTip.
  ///
  /// In es, this message translates to:
  /// **'Ejemplo: «Gasté 25 euros en comida, restaurante, almuerzo con el equipo»'**
  String get onboardingVoiceTip;

  /// No description provided for @onboardingListTitle.
  ///
  /// In es, this message translates to:
  /// **'Ver tus transacciones'**
  String get onboardingListTitle;

  /// No description provided for @onboardingListBody.
  ///
  /// In es, this message translates to:
  /// **'Toca el icono de lista en el dashboard para ver, filtrar y exportar todas tus transacciones.'**
  String get onboardingListBody;

  /// No description provided for @onboardingChartsTitle.
  ///
  /// In es, this message translates to:
  /// **'Gráficos y análisis'**
  String get onboardingChartsTitle;

  /// No description provided for @onboardingChartsBody.
  ///
  /// In es, this message translates to:
  /// **'Accede a los gráficos desde el menú lateral para analizar tus gastos e ingresos por categoría, período o subcategoría.'**
  String get onboardingChartsBody;

  /// No description provided for @onboardingDoneTitle.
  ///
  /// In es, this message translates to:
  /// **'¡Todo listo!'**
  String get onboardingDoneTitle;

  /// No description provided for @onboardingDoneBody.
  ///
  /// In es, this message translates to:
  /// **'Ya conoces lo esencial. Puedes volver a ver este tutorial en cualquier momento desde Ajustes.'**
  String get onboardingDoneBody;

  /// No description provided for @tutorialFinish.
  ///
  /// In es, this message translates to:
  /// **'Finalizar'**
  String get tutorialFinish;

  /// No description provided for @tutorialAddTitle.
  ///
  /// In es, this message translates to:
  /// **'Añade transacciones'**
  String get tutorialAddTitle;

  /// No description provided for @tutorialAddBody.
  ///
  /// In es, this message translates to:
  /// **'Toca el botón + para desplegar las opciones de registro. Puedes añadir con voz, manualmente o fotografiando un recibo.'**
  String get tutorialAddBody;

  /// No description provided for @tutorialVoiceStepTitle.
  ///
  /// In es, this message translates to:
  /// **'🎤 Añadir con voz'**
  String get tutorialVoiceStepTitle;

  /// No description provided for @tutorialVoiceStepBody.
  ///
  /// In es, this message translates to:
  /// **'Di en voz alta el importe, la categoría, la subcategoría y una descripción. Mencionar la palabra \"categoría\" o \"subcategoría\" antes del nombre (p. ej. \"categoría Comida, subcategoría restaurante\") ayuda a la IA a registrar la transacción correctamente.'**
  String get tutorialVoiceStepBody;

  /// No description provided for @tutorialManualStepTitle.
  ///
  /// In es, this message translates to:
  /// **'✏️ Añadir manualmente'**
  String get tutorialManualStepTitle;

  /// No description provided for @tutorialManualStepBody.
  ///
  /// In es, this message translates to:
  /// **'Rellena el formulario con todos los detalles: tipo (gasto/ingreso), categoría, importe, descripción, fecha e incluso recurrencia.'**
  String get tutorialManualStepBody;

  /// No description provided for @tutorialCameraStepTitle.
  ///
  /// In es, this message translates to:
  /// **'📷 Añadir con foto'**
  String get tutorialCameraStepTitle;

  /// No description provided for @tutorialCameraStepBody.
  ///
  /// In es, this message translates to:
  /// **'Fotografía un ticket o recibo y la IA lo interpretará automáticamente y lo añadirá como transacción lista para guardar.'**
  String get tutorialCameraStepBody;

  /// No description provided for @tutorialBalanceTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu resumen financiero'**
  String get tutorialBalanceTitle;

  /// No description provided for @tutorialBalanceBody.
  ///
  /// In es, this message translates to:
  /// **'Aquí ves el balance total, los ingresos y los gastos del período seleccionado. La barra de color muestra la proporción entre ambos.'**
  String get tutorialBalanceBody;

  /// No description provided for @tutorialChartsStepTitle.
  ///
  /// In es, this message translates to:
  /// **'Gráficos de distribución'**
  String get tutorialChartsStepTitle;

  /// No description provided for @tutorialChartsStepBody.
  ///
  /// In es, this message translates to:
  /// **'Toca para ver gráficos de tarta y barras que muestran cómo se distribuyen tus ingresos y gastos por categoría.'**
  String get tutorialChartsStepBody;

  /// No description provided for @tutorialHistoryStepTitle.
  ///
  /// In es, this message translates to:
  /// **'Historial de transacciones'**
  String get tutorialHistoryStepTitle;

  /// No description provided for @tutorialHistoryStepBody.
  ///
  /// In es, this message translates to:
  /// **'Pulsa \"Ver todo\" para acceder al historial completo con filtros, búsqueda y orden personalizado.'**
  String get tutorialHistoryStepBody;

  /// No description provided for @tutorialChatStepTitle.
  ///
  /// In es, this message translates to:
  /// **'✨ Chat con IA'**
  String get tutorialChatStepTitle;

  /// No description provided for @tutorialChatStepBody.
  ///
  /// In es, this message translates to:
  /// **'Habla con tu asistente financiero personal. Puedes preguntarle sobre tus gastos, pedir análisis de tus finanzas o recibir consejos personalizados basados en tus transacciones.'**
  String get tutorialChatStepBody;

  /// No description provided for @tutorialDrawerTitle.
  ///
  /// In es, this message translates to:
  /// **'Menú de configuración'**
  String get tutorialDrawerTitle;

  /// No description provided for @tutorialDrawerBody.
  ///
  /// In es, this message translates to:
  /// **'Desde el menú lateral puedes cambiar el idioma, la moneda, el tema visual y gestionar tu suscripción PRO.'**
  String get tutorialDrawerBody;

  /// No description provided for @labelVoice.
  ///
  /// In es, this message translates to:
  /// **'Voz'**
  String get labelVoice;

  /// No description provided for @labelManual.
  ///
  /// In es, this message translates to:
  /// **'Manual'**
  String get labelManual;

  /// No description provided for @labelPhoto.
  ///
  /// In es, this message translates to:
  /// **'Foto'**
  String get labelPhoto;

  /// No description provided for @cameraOption.
  ///
  /// In es, this message translates to:
  /// **'Cámara'**
  String get cameraOption;

  /// No description provided for @galleryOption.
  ///
  /// In es, this message translates to:
  /// **'Galería'**
  String get galleryOption;

  /// No description provided for @micUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Micrófono no disponible'**
  String get micUnavailable;

  /// No description provided for @voiceAiError.
  ///
  /// In es, this message translates to:
  /// **'Error IA voz [{type}]: {info}'**
  String voiceAiError(String type, String info);

  /// No description provided for @voiceInterpretError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo interpretar. Inténtalo de nuevo.'**
  String get voiceInterpretError;

  /// No description provided for @imageTransactionNotDetected.
  ///
  /// In es, this message translates to:
  /// **'No se pudo detectar una transacción en la imagen.'**
  String get imageTransactionNotDetected;

  /// No description provided for @imageAiError.
  ///
  /// In es, this message translates to:
  /// **'Error IA imagen [{type}]: {info}'**
  String imageAiError(String type, String info);

  /// No description provided for @promoCodeTitle.
  ///
  /// In es, this message translates to:
  /// **'Código promocional'**
  String get promoCodeTitle;

  /// No description provided for @promoCodeHint.
  ///
  /// In es, this message translates to:
  /// **'Introduce tu código'**
  String get promoCodeHint;

  /// No description provided for @apply.
  ///
  /// In es, this message translates to:
  /// **'Aplicar'**
  String get apply;

  /// No description provided for @numberFormat.
  ///
  /// In es, this message translates to:
  /// **'Formato de números'**
  String get numberFormat;

  /// No description provided for @numberFormatDotDecimal.
  ///
  /// In es, this message translates to:
  /// **'1,234.56 — decimal: punto'**
  String get numberFormatDotDecimal;

  /// No description provided for @numberFormatCommaDecimal.
  ///
  /// In es, this message translates to:
  /// **'1.234,56 — decimal: coma'**
  String get numberFormatCommaDecimal;

  /// No description provided for @back.
  ///
  /// In es, this message translates to:
  /// **'Volver'**
  String get back;

  /// No description provided for @pageNotFound.
  ///
  /// In es, this message translates to:
  /// **'Página no encontrada: {error}'**
  String pageNotFound(String error);

  /// No description provided for @moreOptions.
  ///
  /// In es, this message translates to:
  /// **'Más opciones'**
  String get moreOptions;

  /// No description provided for @selectCategoryPrompt.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar categoría'**
  String get selectCategoryPrompt;

  /// No description provided for @privacyPolicy.
  ///
  /// In es, this message translates to:
  /// **'Política de privacidad'**
  String get privacyPolicy;

  /// No description provided for @termsOfService.
  ///
  /// In es, this message translates to:
  /// **'Términos de servicio'**
  String get termsOfService;

  /// No description provided for @deleteAccount.
  ///
  /// In es, this message translates to:
  /// **'Eliminar cuenta'**
  String get deleteAccount;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar tu cuenta?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountContent.
  ///
  /// In es, this message translates to:
  /// **'Esta acción es irreversible. Se eliminarán permanentemente tu cuenta y todos los datos asociados: transacciones, categorías e historial.\n\nSi tienes una suscripción PRO activa, también se cancelará.'**
  String get deleteAccountContent;

  /// No description provided for @deleteAccountError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo eliminar la cuenta. Inténtalo de nuevo.'**
  String get deleteAccountError;

  /// No description provided for @fabOpenMenu.
  ///
  /// In es, this message translates to:
  /// **'Abrir menú de acciones'**
  String get fabOpenMenu;

  /// No description provided for @fabCloseMenu.
  ///
  /// In es, this message translates to:
  /// **'Cerrar menú de acciones'**
  String get fabCloseMenu;

  /// No description provided for @voiceListening.
  ///
  /// In es, this message translates to:
  /// **'Escuchando, toca para detener'**
  String get voiceListening;

  /// No description provided for @voiceProcessing.
  ///
  /// In es, this message translates to:
  /// **'Procesando audio'**
  String get voiceProcessing;

  /// No description provided for @imageProcessing.
  ///
  /// In es, this message translates to:
  /// **'Procesando imagen'**
  String get imageProcessing;

  /// No description provided for @loadingTransactions.
  ///
  /// In es, this message translates to:
  /// **'Cargando transacciones'**
  String get loadingTransactions;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'es', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
