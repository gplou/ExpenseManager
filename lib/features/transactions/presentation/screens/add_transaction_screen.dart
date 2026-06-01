import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/currency_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/ad_banner_footer.dart';
import '../../../../core/widgets/numeric_keypad.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../subscription/subscription_provider.dart';
import '../../data/recurring_transactions_repository.dart';
import '../../data/subcategories_repository.dart';
import '../../domain/parsed_voice_transaction.dart';
import '../../domain/recurring_transaction_model.dart';
import '../../domain/transaction_categories.dart';
import '../../domain/transaction_model.dart';
import '../providers/custom_categories_provider.dart';
import '../providers/subcategories_provider.dart';
import '../providers/transactions_provider.dart';
import '../widgets/add_transaction_widgets.dart';
import '../widgets/category_picker_sheet.dart';
import '../widgets/recent_categories_strip.dart';

/// Presents [AddTransactionScreen] as a draggable bottom sheet covering ~94%
/// of the screen height with rounded top corners. Used as the default entry
/// point for adding/editing transactions throughout the app.
Future<void> showAddTransactionSheet(
  BuildContext context, {
  TransactionModel? transaction,
  ParsedVoiceTransaction? voiceData,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.94,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: AddTransactionScreen(
          transaction: transaction,
          voiceData: voiceData,
        ),
      ),
    ),
  );
}

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key, this.transaction, this.voiceData});

  final TransactionModel? transaction;
  final ParsedVoiceTransaction? voiceData;

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  late TransactionType _type;
  late final AmountKeypadController _keypadController;
  late final TextEditingController _descriptionController;
  final FocusNode _descriptionFocus = FocusNode();
  String? _selectedCategory;
  String? _selectedSubcategory;
  late DateTime _selectedDate;
  bool _isSaving = false;
  bool _isRecurring = false;
  RecurrenceType? _recurrenceType;
  String? _amountError;

  late final PageController _pageController;
  int _currentPage = 0;
  static const Duration _pageAnim = Duration(milliseconds: 250);

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    final v = widget.voiceData;
    _type = t?.type ?? v?.type ?? TransactionType.expense;
    _keypadController = AmountKeypadController();
    final initialAmount = t?.amount ?? v?.amount;
    final hasInitialAmount = initialAmount != null && initialAmount > 0;
    if (hasInitialAmount) {
      _keypadController.setValue(initialAmount);
    }
    _descriptionController =
        TextEditingController(text: t?.description ?? v?.description ?? '');
    _selectedCategory = t?.category ?? v?.category;
    _selectedSubcategory = t?.subcategory ?? v?.subcategory;
    _selectedDate = t?.date ?? v?.date ?? clock.now();

    // Skip directly to the details step when we already have an amount
    // (editing existing tx or voice-parsed data).
    _currentPage = (_isEditing || hasInitialAmount) ? 1 : 0;
    _pageController = PageController(initialPage: _currentPage);

    if (v?.isRecurring == true) {
      _isRecurring = true;
      _recurrenceType = switch (v?.recurrenceType) {
        'weekly' => RecurrenceType.weekly,
        'annual' => RecurrenceType.annual,
        _ => RecurrenceType.monthly,
      };
    }
    if (v?.subcategory != null && v?.category != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        try {
          final repo = ref.read(subcategoriesRepositoryProvider);
          final existing = await repo.getForCategory(v!.category, v.type);
          if (!existing.contains(v.subcategory)) {
            await repo.add(v.category, v.type, v.subcategory!);
            ref.invalidate(allSubcategoriesProvider);
          }
          ref.invalidate(subcategoriesProvider(
            (category: v.category, type: v.type),
          ));
        } catch (e, st) {
          developer.log(
            'Failed to ensure voice subcategory',
            error: e,
            stackTrace: st,
          );
        }
      });
    }
    if (t?.recurringTransactionId != null) {
      _isRecurring = true;
      _loadRecurrenceType(t!.recurringTransactionId!);
    }
  }

  Future<void> _loadRecurrenceType(String recurringId) async {
    final recurring = await ref
        .read(recurringTransactionsRepositoryProvider)
        .getById(recurringId);
    if (recurring != null && mounted) {
      setState(() => _recurrenceType = recurring.recurrenceType);
    }
  }

  @override
  void dispose() {
    _keypadController.dispose();
    _descriptionController.dispose();
    _descriptionFocus.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _goToDetails() async {
    final l10n = AppLocalizations.of(context);
    final amount = _keypadController.resolve();
    if (amount == null || amount <= 0) {
      setState(() => _amountError = l10n.invalidAmount);
      HapticFeedback.heavyImpact().ignore();
      return;
    }
    setState(() => _amountError = null);
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick().ignore();
    await _pageController.animateToPage(
      1,
      duration: _pageAnim,
      curve: Curves.easeOut,
    );
  }

  void _goToAmount() {
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick().ignore();
    _pageController.animateToPage(
      0,
      duration: _pageAnim,
      curve: Curves.easeOut,
    );
  }

  Future<void> _openCategoryPicker() async {
    final accentColor =
        _type.isIncome ? AppColors.sageGreen : AppColors.mutedTerra;
    final accentLight =
        _type.isIncome ? AppColors.sageGreenLight : AppColors.mutedTerraLight;
    final selected = await showCategoryPickerSheet(
      context,
      ref,
      type: _type,
      selectedCategory: _selectedCategory,
      accentColor: accentColor,
      accentLight: accentLight,
    );
    if (selected != null && mounted) {
      setState(() {
        _selectedCategory = selected;
        _selectedSubcategory = null;
      });
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final currentCurrency = ref.read(currencyProvider).value ?? 'EUR';
    final amount = _keypadController.resolve();

    if (amount == null || amount <= 0) {
      setState(() => _amountError = l10n.invalidAmount);
      HapticFeedback.heavyImpact().ignore();
      return;
    }
    setState(() => _amountError = null);

    if (_selectedCategory == null) {
      context.showSnackbar(l10n.selectCategory, isError: true);
      return;
    }
    if (_isRecurring && _recurrenceType == null) {
      context.showSnackbar(l10n.selectFrequency, isError: true);
      return;
    }

    final desc = _descriptionController.text.trim().isEmpty
        ? null
        : _descriptionController.text.trim();

    final tx = _isEditing
        ? widget.transaction!.copyWith(
            amount: amount,
            type: _type,
            category: _selectedCategory!,
            subcategory: _selectedSubcategory,
            description: desc,
            date: _selectedDate,
            currency: currentCurrency,
          )
        : TransactionModel(
            id: '',
            userId: '',
            amount: amount,
            type: _type,
            category: _selectedCategory!,
            subcategory: _selectedSubcategory,
            description: desc,
            date: _selectedDate,
            createdAt: clock.now(),
            currency: currentCurrency,
          );

    setState(() => _isSaving = true);
    try {
      await ref.read(transactionsNotifierProvider.notifier).saveWithRecurrence(
            transaction: tx,
            isEditing: _isEditing,
            isRecurring: _isRecurring,
            recurrenceType: _recurrenceType,
            currency: currentCurrency,
          );
      if (mounted) {
        HapticFeedback.heavyImpact().ignore();
        Navigator.of(context).pop();
      }
    } catch (e, st) {
      developer.log(
        _isEditing ? 'Update transaction failed' : 'Create transaction failed',
        error: e,
        stackTrace: st,
      );
      if (mounted) {
        context.showSnackbar(
          _isEditing ? l10n.errorUpdating : l10n.errorSaving,
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final t = widget.transaction!;
    final isRecurring = t.recurringTransactionId != null;
    final confirmMessage = isRecurring
        ? (t.type.isExpense
            ? l10n.deleteRecurringExpenseConfirm
            : l10n.deleteRecurringIncomeConfirm)
        : l10n.deleteTransactionConfirm;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(confirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.delete,
              style: const TextStyle(color: AppColors.mutedTerra),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref
        .read(transactionsNotifierProvider.notifier)
        .delete(t.id, recurringTransactionId: t.recurringTransactionId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final customCats = ref.watch(
      customCategoriesSyncProvider.select((m) => m[_type] ?? []),
    );

    final accentColor =
        _type.isIncome ? AppColors.sageGreen : AppColors.mutedTerra;
    final accentLight =
        _type.isIncome ? AppColors.sageGreenLight : AppColors.mutedTerraLight;

    final isPro = ref.watch(isProProvider);
    final currencyCode = ref.watch(currencyProvider).value ?? 'EUR';
    final isDetailsStep = _currentPage == 1;

    return PopScope(
      canPop: _currentPage == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _currentPage == 1) {
          _goToAmount();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          leading: isDetailsStep
              ? IconButton(
                  tooltip: l10n.stepAmount,
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: _goToAmount,
                )
              : null,
          title: Text(_isEditing ? l10n.editTransaction : l10n.newTransaction),
          actions: [
            if (isDetailsStep)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: Center(
                  child: AmountPill(
                    controller: _keypadController,
                    type: _type,
                    accent: accentColor,
                    accentLight: accentLight,
                    currencyCode: currencyCode,
                    onTap: _goToAmount,
                  ),
                ),
              ),
            if (_isEditing && !isDetailsStep)
              IconButton(
                tooltip: l10n.delete,
                onPressed: _delete,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.mutedTerra,
                ),
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildBottomAction(l10n, accentColor),
                if (!isPro) const AdBannerFooter(),
              ],
            ),
          ),
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                    AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
                child: TransactionStepIndicator(
                  currentStep: _currentPage,
                  accent: accentColor,
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const ClampingScrollPhysics(),
                  onPageChanged: (i) {
                    if (!mounted) return;
                    setState(() => _currentPage = i);
                  },
                  children: [
                    _buildAmountStep(accentColor, currencyCode),
                    _buildDetailsStep(
                      l10n: l10n,
                      accentColor: accentColor,
                      accentLight: accentLight,
                      customCats: customCats,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountStep(Color accentColor, String currencyCode) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, 0),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TransactionTypeToggle(
            value: _type,
            onChanged: (next) {
              HapticFeedback.selectionClick();
              setState(() {
                _type = next;
                _selectedCategory = null;
                _selectedSubcategory = null;
              });
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          AmountDisplay(
            controller: _keypadController,
            accent: accentColor,
            currencyCode: currencyCode,
            error: _amountError,
          ),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
            child: NumericKeypad(
              controller: _keypadController,
              accent: accentColor,
              submitLabel: l10n.continueAction,
              canSubmit: !_isSaving,
              onSubmit: _goToDetails,
              fillVertical: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsStep({
    required AppLocalizations l10n,
    required Color accentColor,
    required Color accentLight,
    required List<TransactionCategory> customCats,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RecentCategoriesStrip(
            type: _type,
            selected: _selectedCategory,
            accentColor: accentColor,
            accentLight: accentLight,
            onSelect: (cat) {
              setState(() {
                _selectedCategory = cat;
                _selectedSubcategory = null;
              });
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          CategoryBlock(
            type: _type,
            selectedCategory: _selectedCategory,
            selectedSubcategory: _selectedSubcategory,
            accentColor: accentColor,
            accentLight: accentLight,
            customCats: customCats,
            onCategoryTap: _openCategoryPicker,
            onSubcategorySelected: (sub) =>
                setState(() => _selectedSubcategory = sub),
          ),
          const SizedBox(height: AppSpacing.sm),
          InlineDatePicker(
            selected: _selectedDate,
            accent: accentColor,
            onDateChanged: (d) => setState(() => _selectedDate = d),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: DetailsBlock(
                  descriptionController: _descriptionController,
                  descriptionFocus: _descriptionFocus,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              RecurringToggleCompact(
                isRecurring: _isRecurring,
                recurrenceType: _recurrenceType,
                date: _selectedDate,
                accent: accentColor,
                onToggle: (v) => setState(() {
                  _isRecurring = v;
                  _recurrenceType = v ? RecurrenceType.monthly : null;
                }),
                onChangeFrequency: (t) =>
                    setState(() => _recurrenceType = t),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: _isRecurring
                ? Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: RecurringFrequencyPicker(
                      recurrenceType: _recurrenceType,
                      date: _selectedDate,
                      accent: accentColor,
                      onChangeFrequency: (t) =>
                          setState(() => _recurrenceType = t),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction(AppLocalizations l10n, Color accentColor) {
    if (_currentPage == 0) return const SizedBox.shrink();

    final label = _isEditing
        ? l10n.saveChanges
        : (_type.isIncome ? l10n.saveIncome : l10n.saveExpense);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _save,
        icon: const Icon(Icons.check_rounded),
        label: Text(label),
        style: ElevatedButton.styleFrom(backgroundColor: accentColor),
      ),
    );
  }
}
