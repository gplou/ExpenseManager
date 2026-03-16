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
  String get proVoiceAI => 'KI-Spracheingabe';

  @override
  String get proVoiceAISubtitle => 'Transaktionen per Sprache erfassen';

  @override
  String get proFutureFeatures => 'Zukünftige Funktionen';

  @override
  String get proFutureFeaturesSubtitle => 'Frühzeitiger Zugang zu Neuheiten';

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
  String get proPromoUnexpectedError =>
      'Unerwarteter Fehler. Bitte erneut versuchen.';

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
}
