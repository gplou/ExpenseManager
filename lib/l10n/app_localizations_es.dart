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
  String get noRepeat => 'No repetir';

  @override
  String get note => 'Nota';

  @override
  String get more => 'Más';

  @override
  String get weekly => 'Semanal';

  @override
  String get monthly => 'Mensual';

  @override
  String get yearly => 'Anual';

  @override
  String get saveChanges => 'Guardar cambios';

  @override
  String get saveExpense => 'Guardar gasto';

  @override
  String get saveIncome => 'Guardar ingreso';

  @override
  String get continueAction => 'Continuar';

  @override
  String get stepAmount => 'Importe';

  @override
  String get stepDetails => 'Detalles';

  @override
  String nextRepetition(String date, String frequency) {
    return 'La próxima repetición será el $date y cada $frequency a partir de entonces.';
  }

  @override
  String get frequencyWeek => 'semana';

  @override
  String get frequencyMonth => 'mes';

  @override
  String get frequencyYear => 'año';

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
  String get search => 'Buscar';

  @override
  String get searchHint => 'Buscar transacciones…';

  @override
  String get searchNoResults => 'Sin resultados para tu búsqueda';

  @override
  String get appLock => 'Bloqueo de la app';

  @override
  String get appLockSubtitle =>
      'Pedir biometría o código del dispositivo al abrir';

  @override
  String get appLockUnlockReason => 'Desbloquea para acceder a tus finanzas';

  @override
  String get appLockUnavailable =>
      'Configura primero un bloqueo de pantalla en tu dispositivo';

  @override
  String get unlock => 'Desbloquear';

  @override
  String get budgets => 'Presupuestos';

  @override
  String get budgetsManage => 'Gestionar';

  @override
  String get budgetsEmptyCta => 'Crea tu primer presupuesto por categoría';

  @override
  String get budgetNew => 'Nuevo presupuesto';

  @override
  String get budgetEdit => 'Editar presupuesto';

  @override
  String get budgetMonthlyLimit => 'Límite mensual';

  @override
  String get budgetDeleteConfirm =>
      '¿Eliminar este presupuesto? Tus transacciones no se tocan.';

  @override
  String get budgetNoBudgets => 'Sin presupuestos';

  @override
  String get budgetNoBudgetsSubtitle =>
      'Crea un presupuesto mensual por categoría para controlar tu gasto';

  @override
  String budgetNearLimit(String category) {
    return 'Has superado el 80% del presupuesto de $category';
  }

  @override
  String budgetLimitReached(String category) {
    return 'Has alcanzado el presupuesto de $category';
  }

  @override
  String get budgetUpgradeCta => 'Ver PRO';

  @override
  String get errorFreePlanLimit =>
      'El plan gratuito permite 1 presupuesto. Pásate a PRO para crear más.';

  @override
  String get backupExport => 'Exportar copia de seguridad';

  @override
  String get backupExportJson => 'Copia completa (JSON)';

  @override
  String get backupExportCsv => 'Tabla simple (CSV)';

  @override
  String get backupImport => 'Importar copia';

  @override
  String backupImportPreview(int valid, int duplicates, int invalid) {
    return '$valid nuevas, $duplicates duplicadas, $invalid con errores';
  }

  @override
  String backupImportDone(int count) {
    return '$count transacciones importadas';
  }

  @override
  String get backupImportNothing => 'Nada nuevo que importar';

  @override
  String get backupImportError =>
      'No se pudo leer el archivo. Usa una copia exportada por la app.';

  @override
  String get recurringReminders => 'Recordatorios de recurrentes';

  @override
  String get recurringRemindersSubtitle => 'Aviso el día antes de cada cargo';

  @override
  String get recurringReminderTitle => 'Pago recurrente mañana';

  @override
  String recurringReminderBody(String name, String amount) {
    return '$name — $amount';
  }

  @override
  String get notificationsDenied =>
      'Activa las notificaciones de la app en los ajustes del sistema';

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
  String get logoutConfirmTitle => '¿Cerrar sesión?';

  @override
  String get logoutConfirmContent =>
      'Tus datos guardados en este dispositivo se conservan y volverás a verlos al iniciar sesión con la misma cuenta.';

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
  String get showPassword => 'Mostrar contraseña';

  @override
  String get hidePassword => 'Ocultar contraseña';

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
  String get passwordMinChars => 'Mínimo 8 caracteres, una letra y un número';

  @override
  String get enterPasswordRequired => 'Ingresa una contraseña';

  @override
  String get passwordTooShort =>
      'La contraseña debe tener al menos 8 caracteres, una letra y un número';

  @override
  String get accountCreated =>
      '¡Cuenta creada! Revisa tu email para verificarla.';

  @override
  String get relToday => 'Hoy';

  @override
  String get relYesterday => 'Ayer';

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

  @override
  String get proPlanTitle => 'Plan PRO';

  @override
  String get proDrawerSubtitle => 'Desbloquea funciones premium';

  @override
  String proActiveStatus(int days) {
    return 'Activo · expira en $days días';
  }

  @override
  String get proBenefitsTitle => '¿Qué incluye PRO?';

  @override
  String get proNoBannerAds => 'Sin publicidad';

  @override
  String get proNoBannerAdsSubtitle => 'Experiencia limpia, sin interrupciones';

  @override
  String get proVoiceImage => 'Voz e imagen con IA';

  @override
  String get proVoiceImageSubtitle =>
      'Añade transacciones hablando o con una foto';

  @override
  String get proAIChat => 'Chat financiero con IA';

  @override
  String get proAIChatSubtitle =>
      'Consulta tus finanzas con un asistente inteligente';

  @override
  String get proPrice => '€4,99 / mes';

  @override
  String get proPriceSubtitle => 'Cancela cuando quieras';

  @override
  String get proSubscribe => 'Suscribirse';

  @override
  String get proRestorePurchases => 'Restaurar compras';

  @override
  String get proRefreshStatus => 'Actualizar estado';

  @override
  String get proLegalDisclaimer =>
      'El pago se cargará a tu cuenta de la tienda. La suscripción se renueva automáticamente cada mes.';

  @override
  String get proVoiceLockedSubtitle => 'Función exclusiva PRO';

  @override
  String get proHeaderActiveTitle => 'PRO Activo';

  @override
  String get proHeaderInactiveTitle => 'Hazte PRO';

  @override
  String get proHeaderActiveSubtitle => 'Gracias por tu apoyo';

  @override
  String get proHeaderInactiveSubtitle =>
      'Desbloquea todas las funciones premium';

  @override
  String get proActiveCardTitle => 'Suscripción activa';

  @override
  String proActiveCardExpiry(int days, String source) {
    return 'Expira en $days días · $source';
  }

  @override
  String get proSourceGooglePlay => 'Google Play';

  @override
  String get proSourceAppStore => 'App Store';

  @override
  String get proSourcePromoCode => 'Código promo';

  @override
  String get proProductUnavailable =>
      'Producto no disponible. Inténtalo más tarde.';

  @override
  String get proPromoBadInput => 'Introduce un código';

  @override
  String get proPromoSuccess => '¡Código aplicado! Disfruta de PRO.';

  @override
  String proPromoDiscountSuccess(int percentage) {
    return '¡Descuento del $percentage% aplicado! Completa tu compra para activar PRO.';
  }

  @override
  String proDiscountBanner(int percentage, int bonusDays) {
    return 'Descuento $percentage% aplicado — $bonusDays días extra al suscribirte';
  }

  @override
  String get proPromoUnexpectedError => 'Error inesperado. Inténtalo de nuevo.';

  @override
  String get proSourceFreeTrial => 'Prueba gratuita';

  @override
  String get proFreeTrialButton => 'Prueba gratis 3 días';

  @override
  String get proFreeTrialActivated =>
      '¡Prueba activada! Disfruta de PRO durante 3 días.';

  @override
  String get proFreeTrialSubtitle =>
      'Prueba todas las funciones premium sin compromiso';

  @override
  String get proCloudSync => 'Sincronización en la nube';

  @override
  String get proCloudSyncSubtitle =>
      'Tus datos guardados de forma segura y accesibles en todos tus dispositivos';

  @override
  String get subcategory => 'Subcategoría';

  @override
  String get newSubcategory => 'Nueva subcategoría';

  @override
  String get subcategoryName => 'Nombre de la subcategoría';

  @override
  String get exportColumnSubcategory => 'Subcategoría';

  @override
  String get deleteSubcategoryConfirm => '¿Eliminar esta subcategoría?';

  @override
  String get currency => 'Moneda';

  @override
  String get charts => 'Gráficos';

  @override
  String get viewCharts => 'Ver gráficos';

  @override
  String get allCategories => 'Todas las categorías';

  @override
  String get allSubcategories => 'Todas las subcategorías';

  @override
  String get noSubcategory => 'Sin subcategoría';

  @override
  String get chatTitle => 'Asesor Financiero';

  @override
  String get chatPlaceholder => 'Pregunta sobre tus finanzas...';

  @override
  String get chatWelcomeTitle => 'Tu asesor financiero con IA';

  @override
  String get chatWelcomeSubtitle =>
      'Pregunta sobre tus gastos, ingresos y obtén consejos personalizados';

  @override
  String get chatSuggestion1 => '¿Cuánto gasté este mes?';

  @override
  String get chatSuggestion2 => '¿Cuál es mi mayor gasto?';

  @override
  String get chatSuggestion3 => 'Consejos para ahorrar';

  @override
  String get chatError => 'Error al enviar el mensaje';

  @override
  String get chatRateLimit =>
      'Has alcanzado el límite de mensajes. Espera un momento.';

  @override
  String get chatProRequired => 'Función exclusiva PRO';

  @override
  String get tutorialTitle => 'Tutorial';

  @override
  String get tutorialSkip => 'Omitir';

  @override
  String get tutorialNext => 'Siguiente';

  @override
  String get tutorialBack => 'Atrás';

  @override
  String get tutorialStart => '¡Empezar!';

  @override
  String get tutorialDialogTitle => '¿Te enseñamos cómo va?';

  @override
  String get tutorialDialogBody =>
      'Un tour rápido para descubrir lo esencial de la app. Puedes saltarlo y verlo más tarde desde el menú.';

  @override
  String get tutorialDialogStartCta => 'Ver tour';

  @override
  String get tutorialDialogLaterCta => 'Más tarde';

  @override
  String get onboardingWelcomeTitle => '¡Bienvenido a ExpenseManager!';

  @override
  String get onboardingWelcomeBody =>
      'Gestiona tus finanzas de forma inteligente. Vamos a mostrarte cómo sacarle el máximo partido.';

  @override
  String get onboardingManualTitle => 'Añadir manualmente';

  @override
  String get onboardingManualBody =>
      'Toca el botón + del dashboard y selecciona el lápiz. Rellena el importe, tipo, categoría, subcategoría y descripción.';

  @override
  String get onboardingPhotoTitle => 'Añadir con foto';

  @override
  String get onboardingPhotoBody =>
      'Toca el botón + y selecciona la cámara. Fotografía cualquier ticket o recibo y la IA extraerá los datos automáticamente.';

  @override
  String get onboardingVoiceTitle => 'Añadir con voz (PRO)';

  @override
  String get onboardingVoiceBody =>
      'Toca el micrófono y dicta tu transacción. Para mejores resultados, incluye siempre categoría, subcategoría, importe y descripción.';

  @override
  String get onboardingVoiceImportant => '¡Importante! Incluye estos datos:';

  @override
  String get onboardingVoiceBulletAmount => 'Importe: «25 euros»';

  @override
  String get onboardingVoiceBulletCategory => 'Categoría: «comida»';

  @override
  String get onboardingVoiceBulletSubcategory => 'Subcategoría: «restaurante»';

  @override
  String get onboardingVoiceBulletDescription =>
      'Descripción: «almuerzo con clientes»';

  @override
  String get onboardingVoiceTip =>
      'Ejemplo: «Gasté 25 euros en comida, restaurante, almuerzo con el equipo»';

  @override
  String get onboardingListTitle => 'Ver tus transacciones';

  @override
  String get onboardingListBody =>
      'Toca el icono de lista en el dashboard para ver, filtrar y exportar todas tus transacciones.';

  @override
  String get onboardingChartsTitle => 'Gráficos y análisis';

  @override
  String get onboardingChartsBody =>
      'Accede a los gráficos desde el menú lateral para analizar tus gastos e ingresos por categoría, período o subcategoría.';

  @override
  String get onboardingDoneTitle => '¡Todo listo!';

  @override
  String get onboardingDoneBody =>
      'Ya conoces lo esencial. Puedes volver a ver este tutorial en cualquier momento desde Ajustes.';

  @override
  String get tutorialFinish => 'Finalizar';

  @override
  String get tutorialAddTitle => 'Añade transacciones';

  @override
  String get tutorialAddBody =>
      'Toca el botón + para abrir el formulario. Desde ahí puedes registrar la transacción manualmente, dictarla con voz 🎤 o fotografiar un recibo 📷 — la IA rellena el resto.';

  @override
  String get tutorialVoiceStepTitle => '🎤 Añadir con voz';

  @override
  String get tutorialVoiceStepBody =>
      'Di en voz alta el importe, la categoría, la subcategoría y una descripción. Mencionar la palabra \"categoría\" o \"subcategoría\" antes del nombre (p. ej. \"categoría Comida, subcategoría restaurante\") ayuda a la IA a registrar la transacción correctamente.';

  @override
  String get tutorialManualStepTitle => '✏️ Añadir manualmente';

  @override
  String get tutorialManualStepBody =>
      'Rellena el formulario con todos los detalles: tipo (gasto/ingreso), categoría, importe, descripción, fecha e incluso recurrencia.';

  @override
  String get tutorialCameraStepTitle => '📷 Añadir con foto';

  @override
  String get tutorialCameraStepBody =>
      'Fotografía un ticket o recibo y la IA lo interpretará automáticamente y lo añadirá como transacción lista para guardar.';

  @override
  String get tutorialBalanceTitle => 'Tu resumen financiero';

  @override
  String get tutorialBalanceBody =>
      'Aquí ves el balance total, los ingresos y los gastos del período seleccionado. La barra de color muestra la proporción entre ambos.';

  @override
  String get tutorialChartsStepTitle => 'Gráficos de distribución';

  @override
  String get tutorialChartsStepBody =>
      'Toca para ver gráficos de tarta y barras que muestran cómo se distribuyen tus ingresos y gastos por categoría.';

  @override
  String get tutorialHistoryStepTitle => 'Historial de transacciones';

  @override
  String get tutorialHistoryStepBody =>
      'Pulsa \"Ver todo\" para acceder al historial completo con filtros, búsqueda y orden personalizado.';

  @override
  String get tutorialChatStepTitle => '✨ Chat con IA';

  @override
  String get tutorialChatStepBody =>
      'Habla con tu asistente financiero personal. Puedes preguntarle sobre tus gastos, pedir análisis de tus finanzas o recibir consejos personalizados basados en tus transacciones.';

  @override
  String get tutorialDrawerTitle => 'Menú de configuración';

  @override
  String get tutorialDrawerBody =>
      'Desde el menú lateral puedes cambiar el idioma, la moneda, el tema visual y gestionar tu suscripción PRO.';

  @override
  String get labelVoice => 'Voz';

  @override
  String get labelManual => 'Manual';

  @override
  String get labelPhoto => 'Foto';

  @override
  String get labelChat => 'Chat';

  @override
  String get cameraOption => 'Cámara';

  @override
  String get galleryOption => 'Galería';

  @override
  String get micUnavailable => 'Micrófono no disponible';

  @override
  String get voiceInterpretError =>
      'No se pudo interpretar. Inténtalo de nuevo.';

  @override
  String get voiceProcessing => 'Procesando audio';

  @override
  String get imageTransactionNotDetected =>
      'No se pudo detectar una transacción en la imagen.';

  @override
  String get aiProcessingError =>
      'No se pudo procesar tu solicitud. Inténtalo de nuevo.';

  @override
  String get promoCodeTitle => 'Código promocional';

  @override
  String get promoCodeHint => 'Introduce tu código';

  @override
  String get apply => 'Aplicar';

  @override
  String get numberFormat => 'Formato de números';

  @override
  String get numberFormatDotDecimal => '1,234.56 — decimal: punto';

  @override
  String get numberFormatCommaDecimal => '1.234,56 — decimal: coma';

  @override
  String get back => 'Volver';

  @override
  String pageNotFound(String error) {
    return 'Página no encontrada: $error';
  }

  @override
  String get moreOptions => 'Más opciones';

  @override
  String get selectCategoryPrompt => 'Seleccionar categoría';

  @override
  String get privacyPolicy => 'Política de privacidad';

  @override
  String get termsOfService => 'Términos de servicio';

  @override
  String get deleteAccount => 'Eliminar cuenta';

  @override
  String get deleteAccountTitle => '¿Eliminar tu cuenta?';

  @override
  String get deleteAccountContent =>
      'Esta acción es irreversible. Se eliminarán permanentemente tu cuenta y todos los datos asociados: transacciones, categorías e historial.\n\nSi tienes una suscripción PRO activa, también se cancelará.';

  @override
  String get deleteAccountError =>
      'No se pudo eliminar la cuenta. Inténtalo de nuevo.';

  @override
  String get fabOpenMenu => 'Abrir menú de acciones';

  @override
  String get fabCloseMenu => 'Cerrar menú de acciones';

  @override
  String get voiceHintStartListening => 'Toca para grabar tu gasto';

  @override
  String get photoHintStartCamera => 'Toca para escanear un ticket';

  @override
  String get emptyStateVoiceTitle => 'Habla tu primer gasto';

  @override
  String get emptyStateVoiceExample => '\"café 3.50\"';

  @override
  String get emptyStatePhotoTitle => 'Foto del ticket';

  @override
  String get emptyStateManualTitle => 'Añadir manualmente';

  @override
  String get voiceListening => 'Escuchando, toca para detener';

  @override
  String get imageProcessing => 'Procesando imagen';

  @override
  String get loadingTransactions => 'Cargando transacciones';

  @override
  String selectedCount(int count) {
    return '$count seleccionadas';
  }

  @override
  String deleteSelectedConfirm(int count) {
    return '¿Eliminar $count transacción(es) seleccionada(s)?';
  }

  @override
  String get planAnnual => 'Anual';

  @override
  String get planMonthly => 'Mensual';

  @override
  String get planWeekly => 'Semanal';

  @override
  String planPerMonth(String price) {
    return '$price / mes';
  }

  @override
  String get errorGeneric => 'Algo salió mal. Inténtalo de nuevo.';

  @override
  String get errorNetwork =>
      'Error de conexión. Revisa tu red e inténtalo de nuevo.';

  @override
  String get errorServer => 'Error del servidor. Inténtalo más tarde.';

  @override
  String get errorCache => 'No se pudo acceder al almacenamiento local.';

  @override
  String get errorRateLimit =>
      'Demasiadas solicitudes. Espera un momento e inténtalo de nuevo.';

  @override
  String get errorValidation =>
      'Datos no válidos. Revisa la información introducida.';

  @override
  String get errorAuthInvalidCredentials => 'Email o contraseña incorrectos.';

  @override
  String get errorAuthEmailNotConfirmed =>
      'Debes verificar tu email antes de iniciar sesión.';

  @override
  String get errorAuthEmailAlreadyRegistered =>
      'Este email ya está registrado.';

  @override
  String get errorAuthRateLimit =>
      'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.';

  @override
  String get errorAuthCancelled => 'Inicio de sesión cancelado.';

  @override
  String get errorAuthNoConnection =>
      'Sin conexión. Revisa tu red e inténtalo de nuevo.';

  @override
  String get errorAuthGoogleFailed =>
      'No se pudo iniciar sesión con Google. Inténtalo de nuevo.';

  @override
  String get errorAuthAppleFailed =>
      'No se pudo iniciar sesión con Apple. Inténtalo de nuevo.';

  @override
  String get errorAuthSignInFailed =>
      'No se pudo iniciar sesión. Inténtalo de nuevo.';

  @override
  String get errorAuthSignUpFailed =>
      'No se pudo crear la cuenta. Inténtalo de nuevo.';

  @override
  String get errorAuthGeneric => 'Error de autenticación. Inténtalo de nuevo.';

  @override
  String get errorFreeTrialFailed =>
      'No se pudo activar la prueba gratuita. Inténtalo de nuevo.';

  @override
  String get errorPurchaseGeneric =>
      'No se pudo completar la compra. Inténtalo de nuevo.';

  @override
  String get errorRestoreGeneric =>
      'No se pudieron restaurar tus compras. Inténtalo de nuevo.';

  @override
  String errorPromoTooManyAttempts(int seconds) {
    return 'Demasiados intentos. Espera $seconds segundos.';
  }
}
