// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String greeting(String name) {
    return 'Hallo, $name 👋';
  }

  @override
  String get defaultUser => 'Benutzer';

  @override
  String get balance => 'Kontostand';

  @override
  String get income => 'Einnahmen';

  @override
  String get expenses => 'Ausgaben';

  @override
  String get recent => 'Zuletzt';

  @override
  String get seeAll => 'Alle anzeigen';

  @override
  String get noTransactionsPeriod => 'Keine Transaktionen in diesem Zeitraum';

  @override
  String get customRange => 'Benutzerdefinierter Zeitraum';

  @override
  String get periodWeek => 'Woche';

  @override
  String get periodMonth => 'Monat';

  @override
  String get periodYear => 'Jahr';

  @override
  String get typeIncome => 'Einnahme';

  @override
  String get typeExpense => 'Ausgabe';

  @override
  String get newTransaction => 'Neue Transaktion';

  @override
  String get editTransaction => 'Transaktion bearbeiten';

  @override
  String get amount => 'Betrag';

  @override
  String get amountHint => '0,00';

  @override
  String get category => 'Kategorie';

  @override
  String get descriptionOptional => 'Beschreibung (optional)';

  @override
  String get descriptionHint => 'Notiz hinzufügen...';

  @override
  String get date => 'Datum';

  @override
  String get recurringTransaction => 'Wiederkehrende Transaktion';

  @override
  String get noRepeat => 'Nicht wiederholen';

  @override
  String get note => 'Notiz';

  @override
  String get more => 'Mehr';

  @override
  String get weekly => 'Wöchentlich';

  @override
  String get monthly => 'Monatlich';

  @override
  String get yearly => 'Jährlich';

  @override
  String get saveChanges => 'Änderungen speichern';

  @override
  String get saveExpense => 'Ausgabe speichern';

  @override
  String get saveIncome => 'Einnahme speichern';

  @override
  String get continueAction => 'Weiter';

  @override
  String get stepAmount => 'Betrag';

  @override
  String get stepDetails => 'Details';

  @override
  String nextRepetition(String date, String frequency) {
    return 'Die nächste Wiederholung ist am $date und dann jede $frequency.';
  }

  @override
  String get frequencyWeek => 'Woche';

  @override
  String get frequencyMonth => 'Monat';

  @override
  String get frequencyYear => 'Jahr';

  @override
  String get invalidAmount => 'Geben Sie einen gültigen Betrag ein';

  @override
  String get selectCategory => 'Kategorie auswählen';

  @override
  String get selectFrequency => 'Häufigkeit auswählen';

  @override
  String get errorSaving => 'Fehler beim Speichern';

  @override
  String get errorUpdating => 'Fehler beim Aktualisieren';

  @override
  String get delete => 'Löschen';

  @override
  String get deleteTransactionConfirm => 'Diese Transaktion löschen?';

  @override
  String get deleteRecurringTransactionConfirm =>
      'Diese wiederkehrende Transaktion löschen? Alle zukünftigen Abbuchungen werden storniert.';

  @override
  String get deleteRecurringExpenseConfirm =>
      'Diese wiederkehrende Ausgabe löschen? Diese Ausgabe oder Einnahme wird in Zukunft nicht mehr hinzugefügt.';

  @override
  String get deleteRecurringIncomeConfirm =>
      'Diese wiederkehrende Einnahme löschen? Diese Ausgabe oder Einnahme wird in Zukunft nicht mehr hinzugefügt.';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get history => 'Verlauf';

  @override
  String get errorLoading => 'Ladefehler';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get noTransactions => 'Keine Transaktionen';

  @override
  String get today => 'HEUTE';

  @override
  String get yesterday => 'GESTERN';

  @override
  String get expenseDistribution => 'Ausgabenverteilung';

  @override
  String get incomeDistribution => 'Einnahmenverteilung';

  @override
  String get noDataPeriod => 'Keine Daten für diesen Zeitraum';

  @override
  String get userSettings => 'Benutzereinstellungen';

  @override
  String get username => 'Benutzername';

  @override
  String get noName => 'Kein Name';

  @override
  String get email => 'E-Mail';

  @override
  String get changePassword => 'Passwort ändern';

  @override
  String get appSettings => 'App-Einstellungen';

  @override
  String get darkMode => 'Dunkelmodus';

  @override
  String get language => 'Sprache';

  @override
  String get logout => 'Abmelden';

  @override
  String get logoutConfirmTitle => 'Abmelden?';

  @override
  String get logoutConfirmContent =>
      'Deine auf diesem Gerät gespeicherten Daten bleiben erhalten und sind wieder verfügbar, sobald du dich mit demselben Konto anmeldest.';

  @override
  String changePasswordContent(String email) {
    return 'Wir senden Ihnen einen Link zur Passwortänderung an:\n\n$email';
  }

  @override
  String get send => 'Senden';

  @override
  String get checkEmailPassword =>
      'Überprüfen Sie Ihre E-Mail zum Ändern des Passworts';

  @override
  String get errorSendingEmail =>
      'E-Mail konnte nicht gesendet werden. Versuchen Sie es erneut.';

  @override
  String get editName => 'Namen bearbeiten';

  @override
  String get fullName => 'Vollständiger Name';

  @override
  String get save => 'Speichern';

  @override
  String get errorSavingName =>
      'Speichern fehlgeschlagen. Versuchen Sie es erneut.';

  @override
  String get displayUser => 'Benutzer';

  @override
  String get welcome => 'Willkommen';

  @override
  String get loginSubtitle => 'Melden Sie sich an, um fortzufahren';

  @override
  String get emailLabel => 'E-Mail';

  @override
  String get enterEmail => 'E-Mail eingeben';

  @override
  String get invalidEmail => 'Ungültige E-Mail';

  @override
  String get showPassword => 'Passwort anzeigen';

  @override
  String get hidePassword => 'Passwort verbergen';

  @override
  String get passwordLabel => 'Passwort';

  @override
  String get enterPassword => 'Passwort eingeben';

  @override
  String get forgotPassword => 'Passwort vergessen?';

  @override
  String get signIn => 'Anmelden';

  @override
  String get orContinueWith => 'Oder weiter mit';

  @override
  String get continueWithGoogle => 'Mit Google fortfahren';

  @override
  String get continueWithApple => 'Mit Apple fortfahren';

  @override
  String get noAccount => 'Kein Konto? ';

  @override
  String get signUp => 'Registrieren';

  @override
  String get createAccount => 'Konto erstellen';

  @override
  String get registerSubtitle =>
      'Füllen Sie die Daten aus, um sich zu registrieren';

  @override
  String get nameLabel => 'Name';

  @override
  String get enterName => 'Namen eingeben';

  @override
  String get passwordMinChars =>
      'Mindestens 8 Zeichen, ein Buchstabe und eine Zahl';

  @override
  String get enterPasswordRequired => 'Passwort eingeben';

  @override
  String get passwordTooShort =>
      'Das Passwort muss mindestens 8 Zeichen, einen Buchstaben und eine Zahl enthalten';

  @override
  String get accountCreated =>
      'Konto erstellt! Überprüfen Sie Ihre E-Mail zur Verifizierung.';

  @override
  String get relToday => 'Heute';

  @override
  String get relYesterday => 'Gestern';

  @override
  String get relTomorrow => 'Morgen';

  @override
  String get relOverdue => 'Überfällig';

  @override
  String get categorySalary => 'Gehalt';

  @override
  String get categoryFreelance => 'Freiberuflich';

  @override
  String get categoryInvestment => 'Investition';

  @override
  String get categoryGift => 'Geschenk';

  @override
  String get categoryFood => 'Essen';

  @override
  String get categoryTransport => 'Transport';

  @override
  String get categoryHousing => 'Wohnen';

  @override
  String get categoryLeisure => 'Freizeit';

  @override
  String get categoryHealth => 'Gesundheit';

  @override
  String get categoryEducation => 'Bildung';

  @override
  String get categoryClothing => 'Kleidung';

  @override
  String get categoryTechnology => 'Technologie';

  @override
  String get categoryOther => 'Sonstiges';

  @override
  String get newCategory => 'Neue Kategorie';

  @override
  String get categoryName => 'Kategoriename';

  @override
  String get chooseIcon => 'Symbol auswählen';

  @override
  String get exportExcel => 'Nach Excel exportieren';

  @override
  String get exportSuccess => 'In Downloads gespeichert';

  @override
  String get exportError => 'Fehler beim Exportieren der Datei';

  @override
  String get exportColumnDate => 'Datum';

  @override
  String get exportColumnType => 'Typ';

  @override
  String get exportColumnCategory => 'Kategorie';

  @override
  String get exportColumnDescription => 'Beschreibung';

  @override
  String get exportColumnAmount => 'Betrag';

  @override
  String get proPlanTitle => 'PRO-Plan';

  @override
  String get proDrawerSubtitle => 'Premium-Funktionen freischalten';

  @override
  String proActiveStatus(int days) {
    return 'Aktiv · läuft in $days Tagen ab';
  }

  @override
  String get proBenefitsTitle => 'Was ist in PRO enthalten?';

  @override
  String get proNoBannerAds => 'Keine Werbebanner';

  @override
  String get proNoBannerAdsSubtitle =>
      'Saubere Erfahrung, keine Unterbrechungen';

  @override
  String get proVoiceImage => 'Sprache & Bild mit KI';

  @override
  String get proVoiceImageSubtitle =>
      'Transaktionen per Sprache oder Foto hinzufügen';

  @override
  String get proAIChat => 'KI-Finanzchat';

  @override
  String get proAIChatSubtitle =>
      'Fragen Sie Ihre Finanzen mit einem intelligenten Assistenten';

  @override
  String get proPrice => '4,99 € / Monat';

  @override
  String get proPriceSubtitle => 'Jederzeit kündbar';

  @override
  String get proSubscribe => 'Abonnieren';

  @override
  String get proRestorePurchases => 'Käufe wiederherstellen';

  @override
  String get proRefreshStatus => 'Status aktualisieren';

  @override
  String get proLegalDisclaimer =>
      'Die Zahlung wird Ihrem Store-Konto belastet. Das Abonnement verlängert sich automatisch monatlich.';

  @override
  String get proVoiceLockedSubtitle => 'Exklusive PRO-Funktion';

  @override
  String get proHeaderActiveTitle => 'PRO Aktiv';

  @override
  String get proHeaderInactiveTitle => 'PRO werden';

  @override
  String get proHeaderActiveSubtitle => 'Danke für Ihre Unterstützung';

  @override
  String get proHeaderInactiveSubtitle =>
      'Alle Premium-Funktionen freischalten';

  @override
  String get proActiveCardTitle => 'Aktives Abonnement';

  @override
  String proActiveCardExpiry(int days, String source) {
    return 'Läuft in $days Tagen ab · $source';
  }

  @override
  String get proSourceGooglePlay => 'Google Play';

  @override
  String get proSourceAppStore => 'App Store';

  @override
  String get proSourcePromoCode => 'Promo-Code';

  @override
  String get proProductUnavailable =>
      'Produkt nicht verfügbar. Versuchen Sie es später.';

  @override
  String get proPromoBadInput => 'Geben Sie einen Code ein';

  @override
  String get proPromoSuccess => 'Code angewendet! Viel Spaß mit PRO.';

  @override
  String proPromoDiscountSuccess(int percentage) {
    return '$percentage% Rabatt angewendet! Schließe deinen Kauf ab, um PRO zu aktivieren.';
  }

  @override
  String proDiscountBanner(int percentage, int bonusDays) {
    return '$percentage% Rabatt angewendet — $bonusDays Bonustage beim Abonnieren';
  }

  @override
  String get proPromoUnexpectedError =>
      'Unerwarteter Fehler. Bitte erneut versuchen.';

  @override
  String get proSourceFreeTrial => 'Kostenlose Testversion';

  @override
  String get proFreeTrialButton => '3 Tage kostenlos testen';

  @override
  String get proFreeTrialActivated =>
      'Testversion aktiviert! Genieße PRO für 3 Tage.';

  @override
  String get proFreeTrialSubtitle =>
      'Teste alle Premium-Funktionen unverbindlich';

  @override
  String get proCloudSync => 'Cloud-Synchronisation';

  @override
  String get proCloudSyncSubtitle =>
      'Ihre Daten sicher gesichert und auf allen Geräten zugänglich';

  @override
  String get subcategory => 'Unterkategorie';

  @override
  String get newSubcategory => 'Neue Unterkategorie';

  @override
  String get subcategoryName => 'Name der Unterkategorie';

  @override
  String get exportColumnSubcategory => 'Unterkategorie';

  @override
  String get deleteSubcategoryConfirm => 'Diese Unterkategorie löschen?';

  @override
  String get currency => 'Währung';

  @override
  String get charts => 'Diagramme';

  @override
  String get viewCharts => 'Diagramme anzeigen';

  @override
  String get allCategories => 'Alle Kategorien';

  @override
  String get allSubcategories => 'Alle Unterkategorien';

  @override
  String get noSubcategory => 'Ohne Unterkategorie';

  @override
  String get chatTitle => 'Finanzberater';

  @override
  String get chatPlaceholder => 'Fragen Sie zu Ihren Finanzen...';

  @override
  String get chatWelcomeTitle => 'Ihr KI-Finanzberater';

  @override
  String get chatWelcomeSubtitle =>
      'Fragen Sie zu Ihren Ausgaben, Einnahmen und erhalten Sie personalisierte Tipps';

  @override
  String get chatSuggestion1 => 'Wie viel habe ich diesen Monat ausgegeben?';

  @override
  String get chatSuggestion2 => 'Was ist meine größte Ausgabe?';

  @override
  String get chatSuggestion3 => 'Tipps zum Sparen';

  @override
  String get chatError => 'Fehler beim Senden der Nachricht';

  @override
  String get chatRateLimit =>
      'Sie haben das Nachrichtenlimit erreicht. Warten Sie einen Moment.';

  @override
  String get chatProRequired => 'Exklusive PRO-Funktion';

  @override
  String get tutorialTitle => 'Tutorial';

  @override
  String get tutorialSkip => 'Überspringen';

  @override
  String get tutorialNext => 'Weiter';

  @override
  String get tutorialBack => 'Zurück';

  @override
  String get tutorialStart => 'Loslegen!';

  @override
  String get tutorialDialogTitle => 'Lust auf eine kurze Tour?';

  @override
  String get tutorialDialogBody =>
      'Eine kurze Einführung in die wichtigsten Funktionen. Du kannst sie überspringen und jederzeit über das Menü erneut starten.';

  @override
  String get tutorialDialogStartCta => 'Tour starten';

  @override
  String get tutorialDialogLaterCta => 'Später';

  @override
  String get onboardingWelcomeTitle => 'Willkommen bei ExpenseManager!';

  @override
  String get onboardingWelcomeBody =>
      'Verwalten Sie Ihre Finanzen intelligent. Lassen Sie uns Ihnen zeigen, wie Sie das Beste aus der App herausholen.';

  @override
  String get onboardingManualTitle => 'Manuell hinzufügen';

  @override
  String get onboardingManualBody =>
      'Tippen Sie auf die +-Schaltfläche im Dashboard und wählen Sie den Stift. Füllen Sie Betrag, Typ, Kategorie, Unterkategorie und Beschreibung aus.';

  @override
  String get onboardingPhotoTitle => 'Mit Foto hinzufügen';

  @override
  String get onboardingPhotoBody =>
      'Tippen Sie auf die +-Schaltfläche und wählen Sie die Kamera. Fotografieren Sie einen Kassenbon und die KI extrahiert die Daten automatisch.';

  @override
  String get onboardingVoiceTitle => 'Per Sprache hinzufügen (PRO)';

  @override
  String get onboardingVoiceBody =>
      'Tippen Sie auf das Mikrofon und diktieren Sie Ihre Transaktion. Für beste Ergebnisse geben Sie immer Kategorie, Unterkategorie, Betrag und Beschreibung an.';

  @override
  String get onboardingVoiceImportant =>
      'Wichtig! Geben Sie diese Informationen an:';

  @override
  String get onboardingVoiceBulletAmount => 'Betrag: \'25 Euro\'';

  @override
  String get onboardingVoiceBulletCategory => 'Kategorie: \'Essen\'';

  @override
  String get onboardingVoiceBulletSubcategory =>
      'Unterkategorie: \'Restaurant\'';

  @override
  String get onboardingVoiceBulletDescription =>
      'Beschreibung: \'Mittagessen mit Kunden\'';

  @override
  String get onboardingVoiceTip =>
      'Beispiel: \'Ich habe 25 Euro für Essen ausgegeben, Restaurant, Mittagessen mit dem Team\'';

  @override
  String get onboardingListTitle => 'Ihre Transaktionen anzeigen';

  @override
  String get onboardingListBody =>
      'Tippen Sie auf das Listensymbol im Dashboard, um alle Transaktionen anzuzeigen, zu filtern und zu exportieren.';

  @override
  String get onboardingChartsTitle => 'Diagramme & Analysen';

  @override
  String get onboardingChartsBody =>
      'Rufen Sie Diagramme über das Seitenmenü auf, um Ausgaben und Einnahmen nach Kategorie, Zeitraum oder Unterkategorie zu analysieren.';

  @override
  String get onboardingDoneTitle => 'Alles bereit!';

  @override
  String get onboardingDoneBody =>
      'Sie kennen das Wesentliche. Sie können dieses Tutorial jederzeit über die Einstellungen erneut aufrufen.';

  @override
  String get tutorialFinish => 'Abschließen';

  @override
  String get tutorialAddTitle => 'Transaktionen hinzufügen';

  @override
  String get tutorialAddBody =>
      'Tippen Sie auf die +-Schaltfläche, um das Formular zu öffnen. Dort können Sie die Transaktion manuell erfassen, per Sprache 🎤 diktieren oder einen Beleg fotografieren 📷 — die KI ergänzt den Rest.';

  @override
  String get tutorialVoiceStepTitle => '🎤 Per Sprache hinzufügen';

  @override
  String get tutorialVoiceStepBody =>
      'Sagen Sie den Betrag, die Kategorie, die Unterkategorie und eine Beschreibung laut. Das Erwähnen des Worts \"Kategorie\" oder \"Unterkategorie\" vor dem Namen (z. B. \"Kategorie Essen, Unterkategorie Restaurant\") hilft der KI, die Transaktion korrekt zu erfassen.';

  @override
  String get tutorialManualStepTitle => '✏️ Manuell hinzufügen';

  @override
  String get tutorialManualStepBody =>
      'Füllen Sie das Formular mit allen Details aus: Typ (Ausgabe/Einnahme), Kategorie, Betrag, Beschreibung, Datum und sogar Wiederholung.';

  @override
  String get tutorialCameraStepTitle => '📷 Mit Foto hinzufügen';

  @override
  String get tutorialCameraStepBody =>
      'Fotografieren Sie einen Bon oder Beleg und die KI interpretiert ihn automatisch und fügt ihn als speicherbereite Transaktion hinzu.';

  @override
  String get tutorialBalanceTitle => 'Ihre Finanzübersicht';

  @override
  String get tutorialBalanceBody =>
      'Hier sehen Sie den Gesamtsaldo, Einnahmen und Ausgaben des ausgewählten Zeitraums. Der Farbbalken zeigt das Verhältnis zwischen beiden.';

  @override
  String get tutorialChartsStepTitle => 'Verteilungsdiagramme';

  @override
  String get tutorialChartsStepBody =>
      'Tippen Sie, um Kreis- und Balkendiagramme zu sehen, die zeigen, wie sich Ihre Einnahmen und Ausgaben nach Kategorie verteilen.';

  @override
  String get tutorialHistoryStepTitle => 'Transaktionsverlauf';

  @override
  String get tutorialHistoryStepBody =>
      'Tippen Sie auf \"Alle anzeigen\", um auf den vollständigen Verlauf mit Filtern, Suche und benutzerdefinierter Sortierung zuzugreifen.';

  @override
  String get tutorialChatStepTitle => '✨ KI-Chat';

  @override
  String get tutorialChatStepBody =>
      'Chatten Sie mit Ihrem persönlichen Finanzberater. Sie können Fragen zu Ihren Ausgaben stellen, Finanzanalysen anfordern oder personalisierte Tipps basierend auf Ihren Transaktionen erhalten.';

  @override
  String get tutorialDrawerTitle => 'Einstellungsmenü';

  @override
  String get tutorialDrawerBody =>
      'Über das Seitenmenü können Sie Sprache, Währung, visuelles Thema ändern und Ihr PRO-Abonnement verwalten.';

  @override
  String get labelVoice => 'Stimme';

  @override
  String get labelManual => 'Manuell';

  @override
  String get labelPhoto => 'Foto';

  @override
  String get labelChat => 'Chat';

  @override
  String get cameraOption => 'Kamera';

  @override
  String get galleryOption => 'Galerie';

  @override
  String get micUnavailable => 'Mikrofon nicht verfügbar';

  @override
  String get voiceInterpretError =>
      'Konnte nicht interpretiert werden. Versuchen Sie es erneut.';

  @override
  String get voiceProcessing => 'Audio wird verarbeitet';

  @override
  String get imageTransactionNotDetected =>
      'Es konnte keine Transaktion im Bild erkannt werden.';

  @override
  String get aiProcessingError =>
      'Deine Anfrage konnte nicht verarbeitet werden. Bitte versuche es erneut.';

  @override
  String get promoCodeTitle => 'Aktionscode';

  @override
  String get promoCodeHint => 'Code eingeben';

  @override
  String get apply => 'Anwenden';

  @override
  String get numberFormat => 'Zahlenformat';

  @override
  String get numberFormatDotDecimal => '1,234.56 — Dezimal: Punkt';

  @override
  String get numberFormatCommaDecimal => '1.234,56 — Dezimal: Komma';

  @override
  String get back => 'Zurück';

  @override
  String pageNotFound(String error) {
    return 'Seite nicht gefunden: $error';
  }

  @override
  String get moreOptions => 'Mehr Optionen';

  @override
  String get selectCategoryPrompt => 'Kategorie wählen';

  @override
  String get privacyPolicy => 'Datenschutzrichtlinie';

  @override
  String get termsOfService => 'Nutzungsbedingungen';

  @override
  String get deleteAccount => 'Konto löschen';

  @override
  String get deleteAccountTitle => 'Konto wirklich löschen?';

  @override
  String get deleteAccountContent =>
      'Diese Aktion ist unwiderruflich. Dein Konto und alle zugehörigen Daten – Transaktionen, Kategorien und Verlauf – werden dauerhaft gelöscht.\n\nFalls du ein aktives PRO-Abonnement hast, wird dieses ebenfalls gekündigt.';

  @override
  String get deleteAccountError =>
      'Konto konnte nicht gelöscht werden. Bitte erneut versuchen.';

  @override
  String get fabOpenMenu => 'Aktionsmenü öffnen';

  @override
  String get fabCloseMenu => 'Aktionsmenü schließen';

  @override
  String get voiceHintStartListening => 'Tippe, um deine Ausgabe aufzuzeichnen';

  @override
  String get photoHintStartCamera => 'Tippe, um einen Beleg zu scannen';

  @override
  String get emptyStateVoiceTitle => 'Sprich deine erste Ausgabe';

  @override
  String get emptyStateVoiceExample => '„Kaffee 3,50“';

  @override
  String get emptyStatePhotoTitle => 'Foto des Belegs';

  @override
  String get emptyStateManualTitle => 'Manuell hinzufügen';

  @override
  String get voiceListening => 'Hört zu, antippen zum Stoppen';

  @override
  String get imageProcessing => 'Bild wird verarbeitet';

  @override
  String get loadingTransactions => 'Transaktionen werden geladen';

  @override
  String selectedCount(int count) {
    return '$count ausgewählt';
  }

  @override
  String deleteSelectedConfirm(int count) {
    return '$count ausgewählte Transaktion(en) löschen?';
  }

  @override
  String get planAnnual => 'Jährlich';

  @override
  String get planMonthly => 'Monatlich';

  @override
  String get planWeekly => 'Wöchentlich';

  @override
  String planPerMonth(String price) {
    return '$price / Monat';
  }

  @override
  String get errorGeneric =>
      'Etwas ist schiefgelaufen. Bitte versuche es erneut.';

  @override
  String get errorNetwork =>
      'Verbindungsfehler. Prüfe dein Netzwerk und versuche es erneut.';

  @override
  String get errorServer => 'Serverfehler. Bitte versuche es später erneut.';

  @override
  String get errorCache => 'Zugriff auf den lokalen Speicher nicht möglich.';

  @override
  String get errorRateLimit =>
      'Zu viele Anfragen. Warte einen Moment und versuche es erneut.';

  @override
  String get errorValidation =>
      'Ungültige Daten. Bitte überprüfe deine Eingaben.';

  @override
  String get errorAuthInvalidCredentials => 'E-Mail oder Passwort ist falsch.';

  @override
  String get errorAuthEmailNotConfirmed =>
      'Du musst deine E-Mail bestätigen, bevor du dich anmeldest.';

  @override
  String get errorAuthEmailAlreadyRegistered =>
      'Diese E-Mail ist bereits registriert.';

  @override
  String get errorAuthRateLimit =>
      'Zu viele Versuche. Warte ein paar Minuten und versuche es erneut.';

  @override
  String get errorAuthCancelled => 'Anmeldung abgebrochen.';

  @override
  String get errorAuthNoConnection =>
      'Keine Verbindung. Prüfe dein Netzwerk und versuche es erneut.';

  @override
  String get errorAuthGoogleFailed =>
      'Anmeldung mit Google fehlgeschlagen. Bitte versuche es erneut.';

  @override
  String get errorAuthAppleFailed =>
      'Anmeldung mit Apple fehlgeschlagen. Bitte versuche es erneut.';

  @override
  String get errorAuthSignInFailed =>
      'Anmeldung fehlgeschlagen. Bitte versuche es erneut.';

  @override
  String get errorAuthSignUpFailed =>
      'Konto konnte nicht erstellt werden. Bitte versuche es erneut.';

  @override
  String get errorAuthGeneric =>
      'Authentifizierungsfehler. Bitte versuche es erneut.';

  @override
  String get errorFreeTrialFailed =>
      'Kostenlose Testphase konnte nicht aktiviert werden. Bitte versuche es erneut.';

  @override
  String get errorPurchaseGeneric =>
      'Kauf konnte nicht abgeschlossen werden. Bitte versuche es erneut.';

  @override
  String get errorRestoreGeneric =>
      'Deine Käufe konnten nicht wiederhergestellt werden. Bitte versuche es erneut.';

  @override
  String errorPromoTooManyAttempts(int seconds) {
    return 'Zu viele Versuche. Warte $seconds Sekunden.';
  }
}
