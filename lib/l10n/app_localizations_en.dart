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
  String get saveChanges => 'Save changes';

  @override
  String get saveExpense => 'Save expense';

  @override
  String get saveIncome => 'Save income';

  @override
  String nextRepetition(String date, String frequency) {
    return 'The next repetition will be on $date and every $frequency from then on.';
  }

  @override
  String get frequencyWeek => 'week';

  @override
  String get frequencyMonth => 'month';

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
  String get passwordMinChars => 'Minimum 8 characters';

  @override
  String get enterPasswordRequired => 'Enter a password';

  @override
  String get passwordTooShort => 'Password must be at least 8 characters';

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
}
