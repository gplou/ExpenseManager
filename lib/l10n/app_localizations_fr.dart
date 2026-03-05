// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String greeting(String name) {
    return 'Bonjour, $name 👋';
  }

  @override
  String get defaultUser => 'utilisateur';

  @override
  String get balance => 'Solde';

  @override
  String get income => 'Revenus';

  @override
  String get expenses => 'Dépenses';

  @override
  String get recent => 'Récents';

  @override
  String get seeAll => 'Tout voir';

  @override
  String get noTransactionsPeriod => 'Aucune transaction cette période';

  @override
  String get customRange => 'Plage personnalisée';

  @override
  String get periodWeek => 'Semaine';

  @override
  String get periodMonth => 'Mois';

  @override
  String get periodYear => 'Année';

  @override
  String get typeIncome => 'Revenu';

  @override
  String get typeExpense => 'Dépense';

  @override
  String get newTransaction => 'Nouvelle transaction';

  @override
  String get editTransaction => 'Modifier la transaction';

  @override
  String get amount => 'Montant';

  @override
  String get amountHint => '0,00';

  @override
  String get category => 'Catégorie';

  @override
  String get descriptionOptional => 'Description (optionnel)';

  @override
  String get descriptionHint => 'Ajouter une note...';

  @override
  String get date => 'Date';

  @override
  String get recurringTransaction => 'Transaction récurrente';

  @override
  String get weekly => 'Hebdomadaire';

  @override
  String get monthly => 'Mensuel';

  @override
  String get saveChanges => 'Enregistrer les modifications';

  @override
  String get saveExpense => 'Enregistrer la dépense';

  @override
  String get saveIncome => 'Enregistrer le revenu';

  @override
  String nextRepetition(String date, String frequency) {
    return 'La prochaine répétition sera le $date et toutes les $frequency à partir de là.';
  }

  @override
  String get frequencyWeek => 'semaine';

  @override
  String get frequencyMonth => 'mois';

  @override
  String get invalidAmount => 'Entrez un montant valide';

  @override
  String get selectCategory => 'Sélectionnez une catégorie';

  @override
  String get selectFrequency => 'Sélectionnez la fréquence';

  @override
  String get errorSaving => 'Erreur lors de l\'enregistrement';

  @override
  String get errorUpdating => 'Erreur lors de la mise à jour';

  @override
  String get delete => 'Supprimer';

  @override
  String get deleteTransactionConfirm => 'Supprimer cette transaction ?';

  @override
  String get deleteRecurringTransactionConfirm =>
      'Supprimer cette transaction récurrente ? Tous les futurs prélèvements seront annulés.';

  @override
  String get deleteRecurringExpenseConfirm =>
      'Supprimer cette dépense récurrente ? Cette dépense ou ce revenu ne sera plus ajouté à l\'avenir.';

  @override
  String get deleteRecurringIncomeConfirm =>
      'Supprimer ce revenu récurrent ? Cette dépense ou ce revenu ne sera plus ajouté à l\'avenir.';

  @override
  String get cancel => 'Annuler';

  @override
  String get history => 'Historique';

  @override
  String get errorLoading => 'Erreur de chargement';

  @override
  String get retry => 'Réessayer';

  @override
  String get noTransactions => 'Aucune transaction';

  @override
  String get today => 'AUJOURD\'HUI';

  @override
  String get yesterday => 'HIER';

  @override
  String get expenseDistribution => 'Répartition des Dépenses';

  @override
  String get incomeDistribution => 'Répartition des Revenus';

  @override
  String get noDataPeriod => 'Aucune donnée pour cette période';

  @override
  String get userSettings => 'Paramètres utilisateur';

  @override
  String get username => 'Nom d\'utilisateur';

  @override
  String get noName => 'Sans nom';

  @override
  String get email => 'E-mail';

  @override
  String get changePassword => 'Changer le mot de passe';

  @override
  String get appSettings => 'Paramètres de l\'app';

  @override
  String get darkMode => 'Mode sombre';

  @override
  String get language => 'Langue';

  @override
  String get logout => 'Se déconnecter';

  @override
  String changePasswordContent(String email) {
    return 'Nous vous enverrons un lien pour changer votre mot de passe à :\n\n$email';
  }

  @override
  String get send => 'Envoyer';

  @override
  String get checkEmailPassword =>
      'Vérifiez votre e-mail pour changer le mot de passe';

  @override
  String get errorSendingEmail => 'Impossible d\'envoyer l\'e-mail. Réessayez.';

  @override
  String get editName => 'Modifier le nom';

  @override
  String get fullName => 'Nom complet';

  @override
  String get save => 'Enregistrer';

  @override
  String get errorSavingName => 'Impossible d\'enregistrer. Réessayez.';

  @override
  String get displayUser => 'Utilisateur';

  @override
  String get welcome => 'Bienvenue';

  @override
  String get loginSubtitle => 'Connectez-vous pour continuer';

  @override
  String get emailLabel => 'E-mail';

  @override
  String get enterEmail => 'Entrez votre e-mail';

  @override
  String get invalidEmail => 'E-mail invalide';

  @override
  String get passwordLabel => 'Mot de passe';

  @override
  String get enterPassword => 'Entrez votre mot de passe';

  @override
  String get forgotPassword => 'Mot de passe oublié ?';

  @override
  String get signIn => 'Se connecter';

  @override
  String get orContinueWith => 'Ou continuer avec';

  @override
  String get continueWithGoogle => 'Continuer avec Google';

  @override
  String get continueWithApple => 'Continuer avec Apple';

  @override
  String get noAccount => 'Pas de compte ? ';

  @override
  String get signUp => 'S\'inscrire';

  @override
  String get createAccount => 'Créer un compte';

  @override
  String get registerSubtitle =>
      'Complétez les informations pour vous inscrire';

  @override
  String get nameLabel => 'Nom';

  @override
  String get enterName => 'Entrez votre nom';

  @override
  String get passwordMinChars =>
      'Minimum 8 caractères, une lettre et un chiffre';

  @override
  String get enterPasswordRequired => 'Entrez un mot de passe';

  @override
  String get passwordTooShort =>
      'Le mot de passe doit avoir au moins 8 caractères, une lettre et un chiffre';

  @override
  String get accountCreated =>
      'Compte créé ! Vérifiez votre e-mail pour le valider.';

  @override
  String get relToday => 'Aujourd\'hui';

  @override
  String get relTomorrow => 'Demain';

  @override
  String get relOverdue => 'En retard';

  @override
  String get categorySalary => 'Salaire';

  @override
  String get categoryFreelance => 'Freelance';

  @override
  String get categoryInvestment => 'Investissement';

  @override
  String get categoryGift => 'Cadeau';

  @override
  String get categoryFood => 'Alimentation';

  @override
  String get categoryTransport => 'Transport';

  @override
  String get categoryHousing => 'Logement';

  @override
  String get categoryLeisure => 'Loisirs';

  @override
  String get categoryHealth => 'Santé';

  @override
  String get categoryEducation => 'Éducation';

  @override
  String get categoryClothing => 'Vêtements';

  @override
  String get categoryTechnology => 'Technologie';

  @override
  String get categoryOther => 'Autres';

  @override
  String get newCategory => 'Nouvelle catégorie';

  @override
  String get categoryName => 'Nom de la catégorie';

  @override
  String get chooseIcon => 'Choisissez une icône';

  @override
  String get exportExcel => 'Exporter vers Excel';

  @override
  String get exportSuccess => 'Enregistré dans Téléchargements';

  @override
  String get exportError => 'Erreur lors de l\'exportation du fichier';

  @override
  String get exportColumnDate => 'Date';

  @override
  String get exportColumnType => 'Type';

  @override
  String get exportColumnCategory => 'Catégorie';

  @override
  String get exportColumnDescription => 'Description';

  @override
  String get exportColumnAmount => 'Montant';

  @override
  String get proPlanTitle => 'Plan PRO';

  @override
  String get proDrawerSubtitle => 'Débloquez les fonctionnalités premium';

  @override
  String proActiveStatus(int days) {
    return 'Actif · expire dans $days jours';
  }

  @override
  String get proBenefitsTitle => 'Qu\'est-ce qu\'inclut PRO ?';

  @override
  String get proNoBannerAds => 'Sans publicité';

  @override
  String get proNoBannerAdsSubtitle => 'Expérience propre, sans interruptions';

  @override
  String get proVoiceAI => 'Saisie vocale avec IA';

  @override
  String get proVoiceAISubtitle => 'Enregistrez des transactions en parlant';

  @override
  String get proFutureFeatures => 'Fonctionnalités futures';

  @override
  String get proFutureFeaturesSubtitle => 'Accès anticipé aux nouveautés';

  @override
  String get proPrice => '4,99 € / mois';

  @override
  String get proPriceSubtitle => 'Annulez quand vous voulez';

  @override
  String get proSubscribe => 'S\'abonner';

  @override
  String get proRestorePurchases => 'Restaurer les achats';

  @override
  String get proRefreshStatus => 'Actualiser le statut';

  @override
  String get proLegalDisclaimer =>
      'Le paiement sera débité de votre compte de magasin. L\'abonnement se renouvelle automatiquement chaque mois.';

  @override
  String get proVoiceLockedSubtitle => 'Fonctionnalité exclusive PRO';

  @override
  String get proHeaderActiveTitle => 'PRO Actif';

  @override
  String get proHeaderInactiveTitle => 'Passer à PRO';

  @override
  String get proHeaderActiveSubtitle => 'Merci pour votre soutien';

  @override
  String get proHeaderInactiveSubtitle =>
      'Débloquez toutes les fonctionnalités premium';

  @override
  String get proActiveCardTitle => 'Abonnement actif';

  @override
  String proActiveCardExpiry(int days, String source) {
    return 'Expire dans $days jours · $source';
  }

  @override
  String get proSourceGooglePlay => 'Google Play';

  @override
  String get proSourceAppStore => 'App Store';

  @override
  String get proSourcePromoCode => 'Code promo';

  @override
  String get proProductUnavailable =>
      'Produit non disponible. Réessayez plus tard.';

  @override
  String get proPromoBadInput => 'Entrez un code';

  @override
  String get proPromoSuccess => 'Code appliqué ! Profitez de PRO.';

  @override
  String get proPromoUnexpectedError => 'Erreur inattendue. Réessayez.';
}
