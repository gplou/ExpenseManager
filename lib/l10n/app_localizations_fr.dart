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
  String get yearly => 'Annuel';

  @override
  String get saveChanges => 'Enregistrer les modifications';

  @override
  String get saveExpense => 'Enregistrer la dépense';

  @override
  String get saveIncome => 'Enregistrer le revenu';

  @override
  String get continueAction => 'Continuer';

  @override
  String get stepAmount => 'Montant';

  @override
  String get stepDetails => 'Détails';

  @override
  String nextRepetition(String date, String frequency) {
    return 'La prochaine répétition sera le $date et toutes les $frequency à partir de là.';
  }

  @override
  String get frequencyWeek => 'semaine';

  @override
  String get frequencyMonth => 'mois';

  @override
  String get frequencyYear => 'an';

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
  String get showPassword => 'Afficher le mot de passe';

  @override
  String get hidePassword => 'Masquer le mot de passe';

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
  String get proVoiceImage => 'Voix et image avec IA';

  @override
  String get proVoiceImageSubtitle =>
      'Ajoutez des transactions en parlant ou avec une photo';

  @override
  String get proAIChat => 'Chat financier avec IA';

  @override
  String get proAIChatSubtitle =>
      'Consultez vos finances avec un assistant intelligent';

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
  String proPromoDiscountSuccess(int percentage) {
    return 'Réduction de $percentage% appliquée ! Finalisez votre achat pour activer PRO.';
  }

  @override
  String proDiscountBanner(int percentage, int bonusDays) {
    return 'Réduction de $percentage% — $bonusDays jours bonus en vous abonnant';
  }

  @override
  String get proPromoUnexpectedError => 'Erreur inattendue. Réessayez.';

  @override
  String get proSourceFreeTrial => 'Essai gratuit';

  @override
  String get proFreeTrialButton => 'Essai gratuit de 3 jours';

  @override
  String get proFreeTrialActivated =>
      'Essai activé ! Profitez de PRO pendant 3 jours.';

  @override
  String get proFreeTrialSubtitle =>
      'Testez toutes les fonctionnalités premium sans engagement';

  @override
  String get proCloudSync => 'Synchronisation cloud';

  @override
  String get proCloudSyncSubtitle =>
      'Vos données sauvegardées en toute sécurité et accessibles sur tous vos appareils';

  @override
  String get subcategory => 'Sous-catégorie';

  @override
  String get newSubcategory => 'Nouvelle sous-catégorie';

  @override
  String get subcategoryName => 'Nom de la sous-catégorie';

  @override
  String get exportColumnSubcategory => 'Sous-catégorie';

  @override
  String get deleteSubcategoryConfirm => 'Supprimer cette sous-catégorie ?';

  @override
  String get currency => 'Devise';

  @override
  String get charts => 'Graphiques';

  @override
  String get viewCharts => 'Voir les graphiques';

  @override
  String get allCategories => 'Toutes les catégories';

  @override
  String get allSubcategories => 'Toutes les sous-catégories';

  @override
  String get noSubcategory => 'Sans sous-catégorie';

  @override
  String get chatTitle => 'Conseiller Financier';

  @override
  String get chatPlaceholder => 'Posez une question sur vos finances...';

  @override
  String get chatWelcomeTitle => 'Votre conseiller financier IA';

  @override
  String get chatWelcomeSubtitle =>
      'Posez des questions sur vos dépenses, revenus et obtenez des conseils personnalisés';

  @override
  String get chatSuggestion1 => 'Combien ai-je dépensé ce mois-ci ?';

  @override
  String get chatSuggestion2 => 'Quelle est ma plus grosse dépense ?';

  @override
  String get chatSuggestion3 => 'Conseils pour économiser';

  @override
  String get chatError => 'Erreur lors de l\'envoi du message';

  @override
  String get chatRateLimit =>
      'Vous avez atteint la limite de messages. Patientez un moment.';

  @override
  String get chatProRequired => 'Fonction exclusive PRO';

  @override
  String get tutorialTitle => 'Tutoriel';

  @override
  String get tutorialSkip => 'Passer';

  @override
  String get tutorialNext => 'Suivant';

  @override
  String get tutorialBack => 'Retour';

  @override
  String get tutorialStart => 'Commencer !';

  @override
  String get tutorialDialogTitle => 'Envie d\'une visite rapide ?';

  @override
  String get tutorialDialogBody =>
      'Une courte présentation de l\'essentiel. Vous pouvez la passer et la relancer à tout moment depuis le menu.';

  @override
  String get tutorialDialogStartCta => 'Faire la visite';

  @override
  String get tutorialDialogLaterCta => 'Plus tard';

  @override
  String get onboardingWelcomeTitle => 'Bienvenue dans ExpenseManager !';

  @override
  String get onboardingWelcomeBody =>
      'Gérez vos finances intelligemment. Laissez-nous vous montrer comment tirer le meilleur parti de l\'application.';

  @override
  String get onboardingManualTitle => 'Ajouter manuellement';

  @override
  String get onboardingManualBody =>
      'Appuyez sur le bouton + du tableau de bord et sélectionnez le crayon. Renseignez le montant, le type, la catégorie, la sous-catégorie et la description.';

  @override
  String get onboardingPhotoTitle => 'Ajouter avec une photo';

  @override
  String get onboardingPhotoBody =>
      'Appuyez sur le bouton + et sélectionnez la caméra. Photographiez un ticket de caisse et l\'IA extraira les données automatiquement.';

  @override
  String get onboardingVoiceTitle => 'Ajouter par la voix (PRO)';

  @override
  String get onboardingVoiceBody =>
      'Appuyez sur le microphone et dictez votre transaction. Pour de meilleurs résultats, incluez toujours la catégorie, la sous-catégorie, le montant et la description.';

  @override
  String get onboardingVoiceImportant =>
      'Important ! Incluez ces informations :';

  @override
  String get onboardingVoiceBulletAmount => 'Montant : « 25 euros »';

  @override
  String get onboardingVoiceBulletCategory => 'Catégorie : « alimentation »';

  @override
  String get onboardingVoiceBulletSubcategory =>
      'Sous-catégorie : « restaurant »';

  @override
  String get onboardingVoiceBulletDescription =>
      'Description : « déjeuner avec des clients »';

  @override
  String get onboardingVoiceTip =>
      'Exemple : « J\'ai dépensé 25 euros en alimentation, restaurant, déjeuner avec l\'équipe »';

  @override
  String get onboardingListTitle => 'Voir vos transactions';

  @override
  String get onboardingListBody =>
      'Appuyez sur l\'icône de liste dans le tableau de bord pour voir, filtrer et exporter toutes vos transactions.';

  @override
  String get onboardingChartsTitle => 'Graphiques et analyses';

  @override
  String get onboardingChartsBody =>
      'Accédez aux graphiques depuis le menu latéral pour analyser vos dépenses et revenus par catégorie, période ou sous-catégorie.';

  @override
  String get onboardingDoneTitle => 'Tout est prêt !';

  @override
  String get onboardingDoneBody =>
      'Vous connaissez l\'essentiel. Vous pouvez revoir ce tutoriel à tout moment depuis les Paramètres.';

  @override
  String get tutorialFinish => 'Terminer';

  @override
  String get tutorialAddTitle => 'Ajouter des transactions';

  @override
  String get tutorialAddBody =>
      'Appuyez sur le bouton + pour ouvrir le formulaire. Vous pouvez ensuite enregistrer la transaction manuellement, la dicter à la voix 🎤 ou photographier un reçu 📷 — l\'IA s\'occupe du reste.';

  @override
  String get tutorialVoiceStepTitle => '🎤 Ajouter par la voix';

  @override
  String get tutorialVoiceStepBody =>
      'Dites à voix haute le montant, la catégorie, la sous-catégorie et une description. Mentionner le mot \"catégorie\" ou \"sous-catégorie\" avant le nom (ex. \"catégorie Alimentation, sous-catégorie restaurant\") aide l\'IA à enregistrer correctement la transaction.';

  @override
  String get tutorialManualStepTitle => '✏️ Ajouter manuellement';

  @override
  String get tutorialManualStepBody =>
      'Remplissez le formulaire avec tous les détails : type (dépense/revenu), catégorie, montant, description, date et même la récurrence.';

  @override
  String get tutorialCameraStepTitle => '📷 Ajouter par photo';

  @override
  String get tutorialCameraStepBody =>
      'Photographiez un ticket ou reçu et l\'IA l\'interprétera automatiquement et l\'ajoutera comme transaction prête à être enregistrée.';

  @override
  String get tutorialBalanceTitle => 'Votre résumé financier';

  @override
  String get tutorialBalanceBody =>
      'Ici vous voyez le solde total, les revenus et les dépenses de la période sélectionnée. La barre de couleur montre la proportion entre les deux.';

  @override
  String get tutorialChartsStepTitle => 'Graphiques de distribution';

  @override
  String get tutorialChartsStepBody =>
      'Appuyez pour voir des graphiques en camembert et en barres montrant comment vos revenus et dépenses se répartissent par catégorie.';

  @override
  String get tutorialHistoryStepTitle => 'Historique des transactions';

  @override
  String get tutorialHistoryStepBody =>
      'Appuyez sur \"Voir tout\" pour accéder à l\'historique complet avec filtres, recherche et tri personnalisé.';

  @override
  String get tutorialChatStepTitle => '✨ Chat IA';

  @override
  String get tutorialChatStepBody =>
      'Discutez avec votre conseiller financier personnel. Vous pouvez lui poser des questions sur vos dépenses, demander des analyses financières ou recevoir des conseils personnalisés basés sur vos transactions.';

  @override
  String get tutorialDrawerTitle => 'Menu des paramètres';

  @override
  String get tutorialDrawerBody =>
      'Depuis le menu latéral, vous pouvez changer la langue, la devise, le thème visuel et gérer votre abonnement PRO.';

  @override
  String get labelVoice => 'Voix';

  @override
  String get labelManual => 'Manuel';

  @override
  String get labelPhoto => 'Photo';

  @override
  String get labelChat => 'Chat';

  @override
  String get cameraOption => 'Appareil photo';

  @override
  String get galleryOption => 'Galerie';

  @override
  String get micUnavailable => 'Microphone non disponible';

  @override
  String voiceAiError(String type, String info) {
    return 'Erreur IA voix [$type] : $info';
  }

  @override
  String get voiceInterpretError => 'Impossible d\'interpréter. Réessayez.';

  @override
  String get voiceProcessing => 'Traitement audio en cours';

  @override
  String get imageTransactionNotDetected =>
      'Impossible de détecter une transaction dans l\'image.';

  @override
  String imageAiError(String type, String info) {
    return 'Erreur IA image [$type] : $info';
  }

  @override
  String get promoCodeTitle => 'Code promo';

  @override
  String get promoCodeHint => 'Entrez votre code';

  @override
  String get apply => 'Appliquer';

  @override
  String get numberFormat => 'Format des nombres';

  @override
  String get numberFormatDotDecimal => '1,234.56 — décimale : point';

  @override
  String get numberFormatCommaDecimal => '1.234,56 — décimale : virgule';

  @override
  String get back => 'Retour';

  @override
  String pageNotFound(String error) {
    return 'Page non trouvée : $error';
  }

  @override
  String get moreOptions => 'Plus d\'options';

  @override
  String get selectCategoryPrompt => 'Choisir une catégorie';

  @override
  String get privacyPolicy => 'Politique de confidentialité';

  @override
  String get termsOfService => 'Conditions d\'utilisation';

  @override
  String get deleteAccount => 'Supprimer le compte';

  @override
  String get deleteAccountTitle => 'Supprimer votre compte ?';

  @override
  String get deleteAccountContent =>
      'Cette action est irréversible. Votre compte et toutes les données associées — transactions, catégories et historique — seront définitivement supprimés.\n\nSi vous avez un abonnement PRO actif, il sera également annulé.';

  @override
  String get deleteAccountError =>
      'Impossible de supprimer le compte. Veuillez réessayer.';

  @override
  String get fabOpenMenu => 'Ouvrir le menu d\'actions';

  @override
  String get fabCloseMenu => 'Fermer le menu d\'actions';

  @override
  String get voiceHintStartListening =>
      'Touchez pour enregistrer votre dépense';

  @override
  String get photoHintStartCamera => 'Touchez pour scanner un ticket';

  @override
  String get emptyStateVoiceTitle => 'Dictez votre première dépense';

  @override
  String get emptyStateVoiceExample => '« café 3,50 »';

  @override
  String get emptyStatePhotoTitle => 'Photo du ticket';

  @override
  String get emptyStateManualTitle => 'Ajouter manuellement';

  @override
  String get voiceListening => 'Écoute en cours, touchez pour arrêter';

  @override
  String get imageProcessing => 'Traitement de l\'image en cours';

  @override
  String get loadingTransactions => 'Chargement des transactions';

  @override
  String selectedCount(int count) {
    return '$count sélectionnée(s)';
  }

  @override
  String deleteSelectedConfirm(int count) {
    return 'Supprimer $count transaction(s) sélectionnée(s) ?';
  }

  @override
  String get planAnnual => 'Annuel';

  @override
  String get planMonthly => 'Mensuel';

  @override
  String get planWeekly => 'Hebdomadaire';

  @override
  String planPerMonth(String price) {
    return '$price / mois';
  }

  @override
  String get errorGeneric => 'Une erreur s\'est produite. Réessaie.';

  @override
  String get errorNetwork =>
      'Erreur de connexion. Vérifie ton réseau et réessaie.';

  @override
  String get errorServer => 'Erreur du serveur. Réessaie plus tard.';

  @override
  String get errorCache => 'Impossible d\'accéder au stockage local.';

  @override
  String get errorRateLimit =>
      'Trop de requêtes. Patiente un instant et réessaie.';

  @override
  String get errorValidation =>
      'Données non valides. Vérifie les informations saisies.';

  @override
  String get errorAuthInvalidCredentials => 'E-mail ou mot de passe incorrect.';

  @override
  String get errorAuthEmailNotConfirmed =>
      'Tu dois vérifier ton e-mail avant de te connecter.';

  @override
  String get errorAuthEmailAlreadyRegistered =>
      'Cet e-mail est déjà enregistré.';

  @override
  String get errorAuthRateLimit =>
      'Trop de tentatives. Patiente quelques minutes et réessaie.';

  @override
  String get errorAuthCancelled => 'Connexion annulée.';

  @override
  String get errorAuthNoConnection =>
      'Pas de connexion. Vérifie ton réseau et réessaie.';

  @override
  String get errorAuthGoogleFailed =>
      'Connexion avec Google impossible. Réessaie.';

  @override
  String get errorAuthAppleFailed =>
      'Connexion avec Apple impossible. Réessaie.';

  @override
  String get errorAuthSignInFailed => 'Connexion impossible. Réessaie.';

  @override
  String get errorAuthSignUpFailed =>
      'Impossible de créer le compte. Réessaie.';

  @override
  String get errorAuthGeneric => 'Erreur d\'authentification. Réessaie.';

  @override
  String get errorFreeTrialFailed =>
      'Impossible d\'activer l\'essai gratuit. Réessaie.';

  @override
  String get errorPurchaseGeneric =>
      'Impossible de finaliser l\'achat. Réessaie.';

  @override
  String get errorRestoreGeneric =>
      'Impossible de restaurer tes achats. Réessaie.';

  @override
  String errorPromoTooManyAttempts(int seconds) {
    return 'Trop de tentatives. Patiente $seconds secondes.';
  }
}
