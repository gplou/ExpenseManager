// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String greeting(String name) {
    return 'Hello, $name 👋';
  }

  @override
  String get defaultUser => 'user';

  @override
  String get balance => 'Balance';

  @override
  String get income => 'Income';

  @override
  String get expenses => 'Expenses';

  @override
  String get recent => 'Recent';

  @override
  String get seeAll => 'See all';

  @override
  String get noTransactionsPeriod => 'No transactions this period';

  @override
  String get customRange => 'Custom range';

  @override
  String get periodWeek => 'Week';

  @override
  String get periodMonth => 'Month';

  @override
  String get periodYear => 'Year';

  @override
  String get typeIncome => 'Income';

  @override
  String get typeExpense => 'Expense';

  @override
  String get newTransaction => 'New transaction';

  @override
  String get editTransaction => 'Edit transaction';

  @override
  String get amount => 'Amount';

  @override
  String get amountHint => '0.00';

  @override
  String get category => 'Category';

  @override
  String get descriptionOptional => 'Description (optional)';

  @override
  String get descriptionHint => 'Add a note...';

  @override
  String get date => 'Date';

  @override
  String get recurringTransaction => 'Recurring transaction';

  @override
  String get weekly => 'Weekly';

  @override
  String get monthly => 'Monthly';

  @override
  String get yearly => 'Yearly';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get saveExpense => 'Save expense';

  @override
  String get saveIncome => 'Save income';

  @override
  String get continueAction => 'Continue';

  @override
  String get stepAmount => 'Amount';

  @override
  String get stepDetails => 'Details';

  @override
  String nextRepetition(String date, String frequency) {
    return 'The next repetition will be on $date and every $frequency from then on.';
  }

  @override
  String get frequencyWeek => 'week';

  @override
  String get frequencyMonth => 'month';

  @override
  String get frequencyYear => 'year';

  @override
  String get invalidAmount => 'Enter a valid amount';

  @override
  String get selectCategory => 'Select a category';

  @override
  String get selectFrequency => 'Select the frequency';

  @override
  String get errorSaving => 'Error saving';

  @override
  String get errorUpdating => 'Error updating';

  @override
  String get delete => 'Delete';

  @override
  String get deleteTransactionConfirm => 'Delete this transaction?';

  @override
  String get deleteRecurringTransactionConfirm =>
      'Delete this recurring transaction? All future charges will be cancelled.';

  @override
  String get deleteRecurringExpenseConfirm =>
      'Delete this recurring expense? This expense or income will no longer be added in the future.';

  @override
  String get deleteRecurringIncomeConfirm =>
      'Delete this recurring income? This expense or income will no longer be added in the future.';

  @override
  String get cancel => 'Cancel';

  @override
  String get history => 'History';

  @override
  String get errorLoading => 'Error loading';

  @override
  String get retry => 'Retry';

  @override
  String get noTransactions => 'No transactions';

  @override
  String get today => 'TODAY';

  @override
  String get yesterday => 'YESTERDAY';

  @override
  String get expenseDistribution => 'Expense Distribution';

  @override
  String get incomeDistribution => 'Income Distribution';

  @override
  String get noDataPeriod => 'No data for this period';

  @override
  String get userSettings => 'User settings';

  @override
  String get username => 'Username';

  @override
  String get noName => 'No name';

  @override
  String get email => 'Email';

  @override
  String get changePassword => 'Change password';

  @override
  String get appSettings => 'App settings';

  @override
  String get darkMode => 'Dark mode';

  @override
  String get language => 'Language';

  @override
  String get logout => 'Log out';

  @override
  String changePasswordContent(String email) {
    return 'We\'ll send a password reset link to:\n\n$email';
  }

  @override
  String get send => 'Send';

  @override
  String get checkEmailPassword => 'Check your email to change your password';

  @override
  String get errorSendingEmail => 'Could not send the email. Try again.';

  @override
  String get editName => 'Edit name';

  @override
  String get fullName => 'Full name';

  @override
  String get save => 'Save';

  @override
  String get errorSavingName => 'Could not save. Try again.';

  @override
  String get displayUser => 'User';

  @override
  String get welcome => 'Welcome';

  @override
  String get loginSubtitle => 'Sign in to continue';

  @override
  String get emailLabel => 'Email';

  @override
  String get enterEmail => 'Enter your email';

  @override
  String get invalidEmail => 'Invalid email';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get passwordLabel => 'Password';

  @override
  String get enterPassword => 'Enter your password';

  @override
  String get forgotPassword => 'Forgot your password?';

  @override
  String get signIn => 'Sign in';

  @override
  String get orContinueWith => 'Or continue with';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get continueWithApple => 'Continue with Apple';

  @override
  String get noAccount => 'Don\'t have an account? ';

  @override
  String get signUp => 'Sign up';

  @override
  String get createAccount => 'Create account';

  @override
  String get registerSubtitle => 'Complete the details to register';

  @override
  String get nameLabel => 'Name';

  @override
  String get enterName => 'Enter your name';

  @override
  String get passwordMinChars =>
      'Minimum 8 characters, one letter and one number';

  @override
  String get enterPasswordRequired => 'Enter a password';

  @override
  String get passwordTooShort =>
      'Password must have at least 8 characters, one letter and one number';

  @override
  String get accountCreated =>
      'Account created! Check your email to verify it.';

  @override
  String get relToday => 'Today';

  @override
  String get relTomorrow => 'Tomorrow';

  @override
  String get relOverdue => 'Overdue';

  @override
  String get categorySalary => 'Salary';

  @override
  String get categoryFreelance => 'Freelance';

  @override
  String get categoryInvestment => 'Investment';

  @override
  String get categoryGift => 'Gift';

  @override
  String get categoryFood => 'Food';

  @override
  String get categoryTransport => 'Transport';

  @override
  String get categoryHousing => 'Housing';

  @override
  String get categoryLeisure => 'Leisure';

  @override
  String get categoryHealth => 'Health';

  @override
  String get categoryEducation => 'Education';

  @override
  String get categoryClothing => 'Clothing';

  @override
  String get categoryTechnology => 'Technology';

  @override
  String get categoryOther => 'Other';

  @override
  String get newCategory => 'New category';

  @override
  String get categoryName => 'Category name';

  @override
  String get chooseIcon => 'Choose an icon';

  @override
  String get exportExcel => 'Export to Excel';

  @override
  String get exportSuccess => 'Saved to Downloads';

  @override
  String get exportError => 'Error exporting the file';

  @override
  String get exportColumnDate => 'Date';

  @override
  String get exportColumnType => 'Type';

  @override
  String get exportColumnCategory => 'Category';

  @override
  String get exportColumnDescription => 'Description';

  @override
  String get exportColumnAmount => 'Amount';

  @override
  String get proPlanTitle => 'PRO Plan';

  @override
  String get proDrawerSubtitle => 'Unlock premium features';

  @override
  String proActiveStatus(int days) {
    return 'Active · expires in $days days';
  }

  @override
  String get proBenefitsTitle => 'What\'s included in PRO?';

  @override
  String get proNoBannerAds => 'No banner ads';

  @override
  String get proNoBannerAdsSubtitle => 'Clean experience, no interruptions';

  @override
  String get proVoiceImage => 'Voice & image with AI';

  @override
  String get proVoiceImageSubtitle =>
      'Add transactions by speaking or with a photo';

  @override
  String get proAIChat => 'AI financial chat';

  @override
  String get proAIChatSubtitle =>
      'Ask about your finances with a smart assistant';

  @override
  String get proPrice => '€4.99 / month';

  @override
  String get proPriceSubtitle => 'Cancel anytime';

  @override
  String get proSubscribe => 'Subscribe';

  @override
  String get proRestorePurchases => 'Restore purchases';

  @override
  String get proRefreshStatus => 'Refresh status';

  @override
  String get proLegalDisclaimer =>
      'Payment will be charged to your store account. Subscription auto-renews monthly.';

  @override
  String get proVoiceLockedSubtitle => 'PRO exclusive feature';

  @override
  String get proHeaderActiveTitle => 'PRO Active';

  @override
  String get proHeaderInactiveTitle => 'Go PRO';

  @override
  String get proHeaderActiveSubtitle => 'Thank you for your support';

  @override
  String get proHeaderInactiveSubtitle => 'Unlock all premium features';

  @override
  String get proActiveCardTitle => 'Active subscription';

  @override
  String proActiveCardExpiry(int days, String source) {
    return 'Expires in $days days · $source';
  }

  @override
  String get proSourceGooglePlay => 'Google Play';

  @override
  String get proSourceAppStore => 'App Store';

  @override
  String get proSourcePromoCode => 'Promo code';

  @override
  String get proProductUnavailable => 'Product not available. Try again later.';

  @override
  String get proPromoBadInput => 'Enter a code';

  @override
  String get proPromoSuccess => 'Code applied! Enjoy PRO.';

  @override
  String proPromoDiscountSuccess(int percentage) {
    return '$percentage% discount applied! Complete your purchase to activate PRO.';
  }

  @override
  String proDiscountBanner(int percentage, int bonusDays) {
    return '$percentage% discount applied — $bonusDays bonus days when you subscribe';
  }

  @override
  String get proPromoUnexpectedError => 'Unexpected error. Please try again.';

  @override
  String get proSourceFreeTrial => 'Free trial';

  @override
  String get proFreeTrialButton => 'Try free for 3 days';

  @override
  String get proFreeTrialActivated => 'Trial activated! Enjoy PRO for 3 days.';

  @override
  String get proFreeTrialSubtitle =>
      'Try all premium features with no commitment';

  @override
  String get proCloudSync => 'Cloud sync';

  @override
  String get proCloudSyncSubtitle =>
      'Your data safely backed up and accessible on all your devices';

  @override
  String get subcategory => 'Subcategory';

  @override
  String get newSubcategory => 'New subcategory';

  @override
  String get subcategoryName => 'Subcategory name';

  @override
  String get exportColumnSubcategory => 'Subcategory';

  @override
  String get deleteSubcategoryConfirm => 'Delete this subcategory?';

  @override
  String get currency => 'Currency';

  @override
  String get charts => 'Charts';

  @override
  String get viewCharts => 'View charts';

  @override
  String get allCategories => 'All categories';

  @override
  String get allSubcategories => 'All subcategories';

  @override
  String get noSubcategory => 'No subcategory';

  @override
  String get chatTitle => 'Financial Advisor';

  @override
  String get chatPlaceholder => 'Ask about your finances...';

  @override
  String get chatWelcomeTitle => 'Your AI Financial Advisor';

  @override
  String get chatWelcomeSubtitle =>
      'Ask about your expenses, income, and get personalized tips';

  @override
  String get chatSuggestion1 => 'How much did I spend this month?';

  @override
  String get chatSuggestion2 => 'What is my biggest expense?';

  @override
  String get chatSuggestion3 => 'Tips to save money';

  @override
  String get chatError => 'Error sending message';

  @override
  String get chatRateLimit =>
      'You\'ve reached the message limit. Wait a moment.';

  @override
  String get chatProRequired => 'PRO exclusive feature';

  @override
  String get tutorialTitle => 'Tutorial';

  @override
  String get tutorialSkip => 'Skip';

  @override
  String get tutorialNext => 'Next';

  @override
  String get tutorialBack => 'Back';

  @override
  String get tutorialStart => 'Get Started!';

  @override
  String get tutorialDialogTitle => 'Want a quick tour?';

  @override
  String get tutorialDialogBody =>
      'A short walkthrough of the essentials. You can skip it and replay it any time from the menu.';

  @override
  String get tutorialDialogStartCta => 'Take the tour';

  @override
  String get tutorialDialogLaterCta => 'Later';

  @override
  String get onboardingWelcomeTitle => 'Welcome to ExpenseManager!';

  @override
  String get onboardingWelcomeBody =>
      'Manage your finances smartly. Let us show you how to get the most out of the app.';

  @override
  String get onboardingManualTitle => 'Add manually';

  @override
  String get onboardingManualBody =>
      'Tap the + button on the dashboard and select the pencil. Fill in the amount, type, category, subcategory and description.';

  @override
  String get onboardingPhotoTitle => 'Add with photo';

  @override
  String get onboardingPhotoBody =>
      'Tap the + button and select the camera. Take a photo of any receipt and the AI will extract the data automatically.';

  @override
  String get onboardingVoiceTitle => 'Add with voice (PRO)';

  @override
  String get onboardingVoiceBody =>
      'Tap the microphone and dictate your transaction. For best results, always include category, subcategory, amount and description.';

  @override
  String get onboardingVoiceImportant => 'Important! Include these details:';

  @override
  String get onboardingVoiceBulletAmount => 'Amount: \"25 euros\"';

  @override
  String get onboardingVoiceBulletCategory => 'Category: \"food\"';

  @override
  String get onboardingVoiceBulletSubcategory => 'Subcategory: \"restaurant\"';

  @override
  String get onboardingVoiceBulletDescription =>
      'Description: \"lunch with clients\"';

  @override
  String get onboardingVoiceTip =>
      'Example: \"I spent 25 euros on food, restaurant, lunch with the team\"';

  @override
  String get onboardingListTitle => 'View your transactions';

  @override
  String get onboardingListBody =>
      'Tap the list icon on the dashboard to view, filter and export all your transactions.';

  @override
  String get onboardingChartsTitle => 'Charts & analytics';

  @override
  String get onboardingChartsBody =>
      'Access charts from the side menu to analyse your expenses and income by category, period or subcategory.';

  @override
  String get onboardingDoneTitle => 'All set!';

  @override
  String get onboardingDoneBody =>
      'You know the essentials. You can revisit this tutorial anytime from Settings.';

  @override
  String get tutorialFinish => 'Finish';

  @override
  String get tutorialAddTitle => 'Add transactions';

  @override
  String get tutorialAddBody =>
      'Tap the + button to open the form. From there you can record the transaction manually, dictate it by voice 🎤, or photograph a receipt 📷 — the AI fills in the rest.';

  @override
  String get tutorialVoiceStepTitle => '🎤 Add by voice';

  @override
  String get tutorialVoiceStepBody =>
      'Say the amount, category, subcategory and a description aloud. Mentioning the word \"category\" or \"subcategory\" before the name (e.g. \"category Food, subcategory restaurant\") helps the AI record the transaction correctly.';

  @override
  String get tutorialManualStepTitle => '✏️ Add manually';

  @override
  String get tutorialManualStepBody =>
      'Fill in the form with all the details: type (expense/income), category, amount, description, date and even recurrence.';

  @override
  String get tutorialCameraStepTitle => '📷 Add by photo';

  @override
  String get tutorialCameraStepBody =>
      'Photograph a ticket or receipt and the AI will interpret it automatically and add it as a transaction ready to save.';

  @override
  String get tutorialBalanceTitle => 'Your financial summary';

  @override
  String get tutorialBalanceBody =>
      'Here you can see the total balance, income and expenses for the selected period. The colour bar shows the proportion between them.';

  @override
  String get tutorialChartsStepTitle => 'Distribution charts';

  @override
  String get tutorialChartsStepBody =>
      'Tap to see pie and bar charts showing how your income and expenses are distributed by category.';

  @override
  String get tutorialHistoryStepTitle => 'Transaction history';

  @override
  String get tutorialHistoryStepBody =>
      'Tap \"See all\" to access the full history with filters, search and custom sorting.';

  @override
  String get tutorialChatStepTitle => '✨ AI Chat';

  @override
  String get tutorialChatStepBody =>
      'Chat with your personal financial advisor. You can ask about your expenses, request financial analysis or receive personalised tips based on your transactions.';

  @override
  String get tutorialDrawerTitle => 'Settings menu';

  @override
  String get tutorialDrawerBody =>
      'From the side menu you can change the language, currency, visual theme and manage your PRO subscription.';

  @override
  String get labelVoice => 'Voice';

  @override
  String get labelManual => 'Manual';

  @override
  String get labelPhoto => 'Photo';

  @override
  String get labelChat => 'Chat';

  @override
  String get cameraOption => 'Camera';

  @override
  String get galleryOption => 'Gallery';

  @override
  String get micUnavailable => 'Microphone not available';

  @override
  String voiceAiError(String type, String info) {
    return 'Voice AI error [$type]: $info';
  }

  @override
  String get voiceInterpretError => 'Could not interpret. Try again.';

  @override
  String get imageTransactionNotDetected =>
      'Could not detect a transaction in the image.';

  @override
  String imageAiError(String type, String info) {
    return 'Image AI error [$type]: $info';
  }

  @override
  String get promoCodeTitle => 'Promo code';

  @override
  String get promoCodeHint => 'Enter your code';

  @override
  String get apply => 'Apply';

  @override
  String get numberFormat => 'Number format';

  @override
  String get numberFormatDotDecimal => '1,234.56 — decimal: dot';

  @override
  String get numberFormatCommaDecimal => '1.234,56 — decimal: comma';

  @override
  String get back => 'Back';

  @override
  String pageNotFound(String error) {
    return 'Page not found: $error';
  }

  @override
  String get moreOptions => 'More options';

  @override
  String get selectCategoryPrompt => 'Select category';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountTitle => 'Delete your account?';

  @override
  String get deleteAccountContent =>
      'This action is irreversible. Your account and all associated data — transactions, categories and history — will be permanently deleted.\n\nIf you have an active PRO subscription, it will also be cancelled.';

  @override
  String get deleteAccountError =>
      'Could not delete the account. Please try again.';

  @override
  String get fabOpenMenu => 'Open actions menu';

  @override
  String get fabCloseMenu => 'Close actions menu';

  @override
  String get voiceHintStartListening => 'Tap to record your expense';

  @override
  String get photoHintStartCamera => 'Tap to scan a receipt';

  @override
  String get emptyStateVoiceTitle => 'Speak your first expense';

  @override
  String get emptyStateVoiceExample => '\"coffee 3.50\"';

  @override
  String get emptyStatePhotoTitle => 'Photo of the receipt';

  @override
  String get emptyStateManualTitle => 'Add manually';

  @override
  String get voiceListening => 'Listening, tap to stop';

  @override
  String get voiceProcessing => 'Processing audio';

  @override
  String get imageProcessing => 'Processing image';

  @override
  String get loadingTransactions => 'Loading transactions';

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String deleteSelectedConfirm(int count) {
    return 'Delete $count selected transaction(s)?';
  }

  @override
  String get planAnnual => 'Annual';

  @override
  String get planMonthly => 'Monthly';

  @override
  String get planWeekly => 'Weekly';

  @override
  String planPerMonth(String price) {
    return '$price / month';
  }

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get errorNetwork =>
      'Connection error. Check your network and try again.';

  @override
  String get errorServer => 'Server error. Please try again later.';

  @override
  String get errorCache => 'Couldn\'t access local storage.';

  @override
  String get errorRateLimit =>
      'Too many requests. Wait a moment and try again.';

  @override
  String get errorValidation =>
      'Invalid data. Please review the information entered.';

  @override
  String get errorAuthInvalidCredentials => 'Incorrect email or password.';

  @override
  String get errorAuthEmailNotConfirmed =>
      'You must verify your email before signing in.';

  @override
  String get errorAuthEmailAlreadyRegistered =>
      'This email is already registered.';

  @override
  String get errorAuthRateLimit =>
      'Too many attempts. Wait a few minutes and try again.';

  @override
  String get errorAuthCancelled => 'Sign-in cancelled.';

  @override
  String get errorAuthNoConnection =>
      'No connection. Check your network and try again.';

  @override
  String get errorAuthGoogleFailed =>
      'Couldn\'t sign in with Google. Please try again.';

  @override
  String get errorAuthAppleFailed =>
      'Couldn\'t sign in with Apple. Please try again.';

  @override
  String get errorAuthSignInFailed => 'Couldn\'t sign in. Please try again.';

  @override
  String get errorAuthSignUpFailed =>
      'Couldn\'t create the account. Please try again.';

  @override
  String get errorAuthGeneric => 'Authentication error. Please try again.';

  @override
  String get errorFreeTrialFailed =>
      'Couldn\'t start the free trial. Please try again.';

  @override
  String get errorPurchaseGeneric =>
      'Couldn\'t complete the purchase. Please try again.';

  @override
  String get errorRestoreGeneric =>
      'Couldn\'t restore your purchases. Please try again.';

  @override
  String errorPromoTooManyAttempts(int seconds) {
    return 'Too many attempts. Wait $seconds seconds.';
  }
}
