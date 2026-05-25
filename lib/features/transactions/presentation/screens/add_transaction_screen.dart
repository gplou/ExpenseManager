import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/router.dart';
import '../../../../core/providers/currency_provider.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/image_input_gateway.dart';
import '../../../../core/services/voice_input_gateway.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_elevation.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/ad_banner_footer.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/numeric_keypad.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../subscription/subscription_provider.dart';
import '../../data/image_transaction_parser.dart';
import '../../data/recurring_transactions_repository.dart';
import '../../data/subcategories_repository.dart';
import '../../data/voice_transaction_parser.dart';
import '../../domain/parsed_voice_transaction.dart';
import '../../domain/recurring_transaction_model.dart';
import '../../domain/transaction_categories.dart';
import '../../domain/transaction_model.dart';
import '../providers/custom_categories_provider.dart';
import '../providers/subcategories_provider.dart';
import '../providers/transactions_provider.dart';
import '../widgets/category_picker_sheet.dart';
import '../widgets/create_subcategory_dialog.dart';
import '../widgets/recent_categories_strip.dart';

enum _CaptureState { idle, listening, voiceProcessing, imageProcessing }

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

// ── Recurring frequency picker (segmented + info) ────────────────────────────

class _RecurringFrequencyPicker extends StatelessWidget {
  const _RecurringFrequencyPicker({
    required this.recurrenceType,
    required this.date,
    required this.accent,
    required this.onChangeFrequency,
  });

  final RecurrenceType? recurrenceType;
  final DateTime date;
  final Color accent;
  final ValueChanged<RecurrenceType> onChangeFrequency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = recurrenceType ?? RecurrenceType.monthly;
    final next = nextRecurrenceDate(date, type);
    final dayStr =
        '${next.day.toString().padLeft(2, '0')}/${next.month.toString().padLeft(2, '0')}/${next.year}';
    final freq = switch (type) {
      RecurrenceType.weekly => l10n.frequencyWeek,
      RecurrenceType.monthly => l10n.frequencyMonth,
      RecurrenceType.annual => l10n.frequencyYear,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<RecurrenceType>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: RecurrenceType.weekly,
              label: Text(l10n.weekly),
              icon: const Icon(Icons.calendar_view_week_outlined, size: 16),
            ),
            ButtonSegment(
              value: RecurrenceType.monthly,
              label: Text(l10n.monthly),
              icon: const Icon(Icons.calendar_month_outlined, size: 16),
            ),
            ButtonSegment(
              value: RecurrenceType.annual,
              label: Text(l10n.yearly),
              icon: const Icon(Icons.event_repeat_outlined, size: 16),
            ),
          ],
          selected: {type},
          onSelectionChanged: (s) => onChangeFrequency(s.first),
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: AppColors.dustyTealLight,
            borderRadius: AppRadius.radiusMd,
          ),
          child: Row(
            children: [
              const Icon(Icons.repeat_rounded,
                  size: 14, color: AppColors.dustyTeal),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  l10n.nextRepetition(dayStr, freq),
                  style: const TextStyle(
                    fontFamily: 'GeneralSans',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.dustyTeal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

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

  late final VoiceInputGateway _speech;
  late final VoiceTransactionParser _voiceParser;
  late final ImageInputGateway _imagePicker;
  late final ImageTransactionParser _imageParser;
  _CaptureState _capture = _CaptureState.idle;

  bool get _isEditing => widget.transaction != null;
  bool get _isCapturing => _capture != _CaptureState.idle;

  static String _speechLocaleId(String code) => switch (code) {
        'es' => 'es_ES',
        'en' => 'en_US',
        'fr' => 'fr_FR',
        'de' => 'de_DE',
        _ => 'en_US',
      };

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
    _selectedDate = t?.date ?? v?.date ?? DateTime.now();

    // Skip directly to the details step when we already have an amount
    // (editing existing tx or voice-parsed data).
    _currentPage = (_isEditing || hasInitialAmount) ? 1 : 0;
    _pageController = PageController(initialPage: _currentPage);

    _speech = ref.read(voiceInputGatewayProvider);
    _voiceParser = ref.read(voiceTransactionParserProvider);
    _imagePicker = ref.read(imageInputGatewayProvider);
    _imageParser = ref.read(imageTransactionParserProvider);

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
    _speech.stop();
    _keypadController.dispose();
    _descriptionController.dispose();
    _descriptionFocus.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ── AI capture (voice + photo) ─────────────────────────────────────────────

  bool _requirePro() {
    if (ref.read(isProProvider)) return true;
    context.push(AppRoutes.pro);
    return false;
  }

  Future<void> _startVoice() async {
    if (_isCapturing) return;
    if (!_requirePro()) return;

    final available = await _speech.initialize(
      onError: (_) {
        if (mounted) setState(() => _capture = _CaptureState.idle);
      },
    );
    if (!available) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.micUnavailable)),
        );
      }
      return;
    }

    setState(() => _capture = _CaptureState.listening);
    AnalyticsService.track(AnalyticsService.voiceUsed);
    final langCode = ref.read(localeProvider).value?.languageCode ?? 'es';
    await _speech.listen(
      localeId: _speechLocaleId(langCode),
      onResult: (result) {
        if (result.finalResult) _processVoice(result.recognizedWords);
      },
    );
  }

  Future<void> _processVoice(String text) async {
    if (text.trim().isEmpty) {
      if (mounted) setState(() => _capture = _CaptureState.idle);
      return;
    }
    setState(() => _capture = _CaptureState.voiceProcessing);
    ParsedVoiceTransaction? parsed;
    try {
      parsed = await _voiceParser.parse(text);
    } catch (e) {
      if (!mounted) return;
      setState(() => _capture = _CaptureState.idle);
      final info = e.toString().split('\n').first;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(l10n.voiceAiError(e.runtimeType.toString(), info)),
        ),
      );
      return;
    }
    if (!mounted) return;
    if (parsed == null) {
      setState(() => _capture = _CaptureState.idle);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).voiceInterpretError),
        ),
      );
      return;
    }
    await _speech.stop();
    if (!mounted) return;
    setState(() => _capture = _CaptureState.idle);
    await _applyParsed(parsed);
  }

  Future<void> _startCamera() async {
    if (_isCapturing) return;
    if (!_requirePro()) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: Text(l10n.cameraOption),
                  onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: Text(l10n.galleryOption),
                  onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (source == null || !mounted) return;

    final XFile? picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    AnalyticsService.track(AnalyticsService.photoUsed, {'source': source.name});
    await _processImage(picked);
  }

  Future<void> _processImage(XFile pickedFile) async {
    if (!mounted) return;
    setState(() => _capture = _CaptureState.imageProcessing);

    File? tempFile;
    try {
      tempFile = File(pickedFile.path);
      final bytes = await tempFile.readAsBytes();
      final parsed = await _imageParser.parse(bytes);
      if (!mounted) return;
      setState(() => _capture = _CaptureState.idle);
      if (parsed == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).imageTransactionNotDetected,
            ),
          ),
        );
        return;
      }
      await _applyParsed(parsed);
    } catch (e) {
      if (mounted) {
        setState(() => _capture = _CaptureState.idle);
        final info = e.toString().split('\n').first;
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(l10n.imageAiError(e.runtimeType.toString(), info)),
          ),
        );
      }
    } finally {
      try {
        if (tempFile != null && await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
    }
  }

  Future<void> _applyParsed(ParsedVoiceTransaction parsed) async {
    final hasAmount = parsed.amount > 0;
    setState(() {
      _type = parsed.type;
      _selectedCategory = parsed.category;
      _selectedSubcategory = parsed.subcategory;
      if (parsed.description != null && parsed.description!.isNotEmpty) {
        _descriptionController.text = parsed.description!;
      }
      if (parsed.date != null) _selectedDate = parsed.date!;
      if (parsed.isRecurring) {
        _isRecurring = true;
        _recurrenceType = switch (parsed.recurrenceType) {
          'weekly' => RecurrenceType.weekly,
          'annual' => RecurrenceType.annual,
          _ => RecurrenceType.monthly,
        };
      }
      if (hasAmount) {
        _keypadController.setValue(parsed.amount);
        _amountError = null;
      }
    });
    if (parsed.subcategory != null && parsed.subcategory!.isNotEmpty) {
      try {
        final repo = ref.read(subcategoriesRepositoryProvider);
        final existing =
            await repo.getForCategory(parsed.category, parsed.type);
        if (!existing.contains(parsed.subcategory)) {
          await repo.add(parsed.category, parsed.type, parsed.subcategory!);
        }
        ref.invalidate(subcategoriesProvider(
          (category: parsed.category, type: parsed.type),
        ));
      } catch (e, st) {
        developer.log(
          'Failed to ensure parsed subcategory',
          error: e,
          stackTrace: st,
        );
      }
    }
    if (hasAmount && mounted && _currentPage == 0) {
      await _pageController.animateToPage(
        1,
        duration: _pageAnim,
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _goToDetails() async {
    final l10n = AppLocalizations.of(context);
    final amount = _keypadController.resolve();
    if (amount == null || amount <= 0) {
      setState(() => _amountError = l10n.invalidAmount);
      HapticFeedback.heavyImpact();
      return;
    }
    setState(() => _amountError = null);
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    await _pageController.animateToPage(
      1,
      duration: _pageAnim,
      curve: Curves.easeOut,
    );
  }

  void _goToAmount() {
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
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
      HapticFeedback.heavyImpact();
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

    setState(() => _isSaving = true);
    try {
      if (_isEditing) {
        final updated = widget.transaction!.copyWith(
          amount: amount,
          type: _type,
          category: _selectedCategory!,
          subcategory: _selectedSubcategory,
          description: desc,
          date: _selectedDate,
          currency: currentCurrency,
        );

        final existingRecurringId = widget.transaction!.recurringTransactionId;
        if (_isRecurring && _recurrenceType != null) {
          final nextDate = nextRecurrenceDate(_selectedDate, _recurrenceType!);
          if (existingRecurringId != null) {
            await ref
                .read(recurringTransactionsRepositoryProvider)
                .updateRecurring(
                  id: existingRecurringId,
                  amount: amount,
                  type: _type,
                  category: _selectedCategory!,
                  subcategory: _selectedSubcategory,
                  description: desc,
                  recurrenceType: _recurrenceType!,
                  nextOccurrence: nextDate,
                );
            await ref
                .read(transactionsNotifierProvider.notifier)
                .update(updated);
          } else {
            final recurringId = await ref
                .read(recurringTransactionsRepositoryProvider)
                .createRecurring(
                  amount: amount,
                  type: _type,
                  category: _selectedCategory!,
                  subcategory: _selectedSubcategory,
                  description: desc,
                  recurrenceType: _recurrenceType!,
                  nextOccurrence: nextDate,
                );
            await ref
                .read(transactionsNotifierProvider.notifier)
                .update(updated.copyWith(recurringTransactionId: recurringId));
          }
        } else {
          if (existingRecurringId != null) {
            await ref
                .read(recurringTransactionsRepositoryProvider)
                .deleteRecurring(existingRecurringId);
          }
          await ref
              .read(transactionsNotifierProvider.notifier)
              .update(updated.copyWith(recurringTransactionId: null));
        }
      } else {
        String? recurringId;
        if (_isRecurring && _recurrenceType != null) {
          final nextDate = nextRecurrenceDate(_selectedDate, _recurrenceType!);
          recurringId = await ref
              .read(recurringTransactionsRepositoryProvider)
              .createRecurring(
                amount: amount,
                type: _type,
                category: _selectedCategory!,
                subcategory: _selectedSubcategory,
                description: desc,
                recurrenceType: _recurrenceType!,
                nextOccurrence: nextDate,
              );
        }
        final transaction = TransactionModel(
          id: '',
          userId: '',
          amount: amount,
          type: _type,
          category: _selectedCategory!,
          subcategory: _selectedSubcategory,
          description: desc,
          date: _selectedDate,
          createdAt: DateTime.now(),
          recurringTransactionId: recurringId,
          currency: currentCurrency,
        );
        await ref
            .read(transactionsNotifierProvider.notifier)
            .create(transaction);
      }
      if (mounted) {
        HapticFeedback.heavyImpact();
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
    final String confirmMessage;
    if (isRecurring) {
      confirmMessage = t.type.isExpense
          ? l10n.deleteRecurringExpenseConfirm
          : l10n.deleteRecurringIncomeConfirm;
    } else {
      confirmMessage = l10n.deleteTransactionConfirm;
    }
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
        .delete(widget.transaction!.id, recurringTransactionId: widget.transaction!.recurringTransactionId);
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
                  child: _AmountPill(
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
        body: Stack(
          children: [
            GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.opaque,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                        AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
                    child: _StepIndicator(
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
            if (_isCapturing)
              _CaptureOverlay(
                state: _capture,
                onStop: () async {
                  await _speech.stop();
                  if (mounted) {
                    setState(() => _capture = _CaptureState.idle);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  // ── Step 1: type + amount ──────────────────────────────────────────────────
  Widget _buildAmountStep(Color accentColor, String currencyCode) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, 0),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TypeToggle(
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
          if (!_isEditing) ...[
            const SizedBox(height: AppSpacing.sm),
            _AiShortcutsRow(
              voiceLabel: l10n.labelVoice,
              photoLabel: l10n.labelPhoto,
              disabled: _isCapturing,
              onVoiceTap: _startVoice,
              onPhotoTap: _startCamera,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          _AmountDisplay(
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

  // ── Step 2: category, subcategory, date, description, recurring ────────────
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
          _CategoryBlock(
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
          _InlineDatePicker(
            selected: _selectedDate,
            accent: accentColor,
            onDateChanged: (d) => setState(() => _selectedDate = d),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _DetailsBlock(
                  descriptionController: _descriptionController,
                  descriptionFocus: _descriptionFocus,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _RecurringToggleCompact(
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
                    child: _RecurringFrequencyPicker(
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
    final isAmountStep = _currentPage == 0;
    // Step 1 renders the keypad inline in the body so the amount card and
    // the numbers sit visually adjacent. No bottom action needed.
    if (isAmountStep) return const SizedBox.shrink();

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

// ── Type toggle (Expense / Income) ────────────────────────────────────────────

class _TypeToggle extends StatelessWidget {
  const _TypeToggle({required this.value, required this.onChanged});

  final TransactionType value;
  final ValueChanged<TransactionType> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: AppRadius.radiusLg,
      ),
      child: Row(
        children: TransactionType.values.map((type) {
          final isSelected = value == type;
          final isIncome = type.isIncome;
          final color = isIncome ? AppColors.sageGreen : AppColors.mutedTerra;
          final iconData = isIncome
              ? Icons.trending_up_rounded
              : Icons.trending_down_rounded;
          return Expanded(
            child: Semantics(
              button: true,
              selected: isSelected,
              label: type.l10nLabel(l10n),
              child: GestureDetector(
                onTap: () => onChanged(type),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? cs.surface : Colors.transparent,
                    borderRadius: AppRadius.radiusMd,
                    boxShadow: isSelected ? AppColors.softShadowSm : AppElevation.e0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        iconData,
                        size: 18,
                        color: isSelected ? color : AppColors.textMuted,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        type.l10nLabel(l10n),
                        style: TextStyle(
                          fontFamily: 'GeneralSans',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? color : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Amount display (no editable, viene del keypad) ────────────────────────────

class _AmountDisplay extends StatelessWidget {
  const _AmountDisplay({
    required this.controller,
    required this.accent,
    required this.currencyCode,
    required this.error,
  });

  final AmountKeypadController controller;
  final Color accent;
  final String currencyCode;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final hasValue = controller.current.isNotEmpty;
        final pendingOp = controller.pendingOpSymbol;
        final previous = controller.previousText;

        return AppCard(
          variant: AppCardVariant.outlined,
          accent: accent,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
          semanticLabel:
              '${l10n.amountHint}: ${hasValue ? controller.current : "0"} $currencyCode',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (previous != null && pendingOp != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(
                    '$previous $pendingOp',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'GeneralSans',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: accent.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '${currencySymbol(currencyCode)} ',
                    style: TextStyle(
                      fontFamily: 'GeneralSans',
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: accent.withValues(alpha: 0.55),
                    ),
                  ),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        hasValue ? controller.current : '0',
                        style: TextStyle(
                          fontFamily: 'GeneralSans',
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: hasValue
                              ? accent
                              : accent.withValues(alpha: 0.25),
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: AppRadius.radiusPill,
                      border: Border.all(
                          color: accent.withValues(alpha: 0.3), width: 1),
                    ),
                    child: Text(
                      currencyCode,
                      style: TextStyle(
                        fontFamily: 'GeneralSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ),
              if (error != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 14,
                      color: AppColors.mutedTerra,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      error!,
                      style: const TextStyle(
                        fontFamily: 'GeneralSans',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.mutedTerra,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── Inline calendar date picker ───────────────────────────────────────────────

class _InlineDatePicker extends StatelessWidget {
  const _InlineDatePicker({
    required this.selected,
    required this.accent,
    required this.onDateChanged,
  });

  final DateTime selected;
  final Color accent;
  final ValueChanged<DateTime> onDateChanged;

  static const double _scale = 0.78;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.borderLight, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: AppRadius.radiusLg,
        child: ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: _scale,
            child: Transform.scale(
              scale: _scale,
              alignment: Alignment.topCenter,
              child: Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: cs.copyWith(
                    primary: accent,
                    onPrimary: AppColors.pureWhite,
                  ),
                ),
                child: CalendarDatePicker(
                  initialDate: selected,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  onDateChanged: onDateChanged,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Recurring toggle compacto (chip icon + switch) ───────────────────────────

class _RecurringToggleCompact extends StatelessWidget {
  const _RecurringToggleCompact({
    required this.isRecurring,
    required this.recurrenceType,
    required this.date,
    required this.accent,
    required this.onToggle,
    required this.onChangeFrequency,
  });

  final bool isRecurring;
  final RecurrenceType? recurrenceType;
  final DateTime date;
  final Color accent;
  final ValueChanged<bool> onToggle;
  final ValueChanged<RecurrenceType> onChangeFrequency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      toggled: isRecurring,
      label: l10n.recurringTransaction,
      child: GestureDetector(
        onTap: () => onToggle(!isRecurring),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(AppSpacing.sm + 2),
          decoration: BoxDecoration(
            color: isRecurring
                ? AppColors.dustyTealLight
                : cs.surfaceContainerHigh,
            borderRadius: AppRadius.radiusMd,
            border: Border.all(
              color: isRecurring ? AppColors.dustyTeal : AppColors.borderLight,
              width: 1.5,
            ),
          ),
          child: Icon(
            Icons.repeat_rounded,
            size: 20,
            color: isRecurring ? AppColors.dustyTeal : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

// ── Category block: categoría full-width + subcategoría indentada ─────────────

class _CategoryBlock extends StatelessWidget {
  const _CategoryBlock({
    required this.type,
    required this.selectedCategory,
    required this.selectedSubcategory,
    required this.accentColor,
    required this.accentLight,
    required this.customCats,
    required this.onCategoryTap,
    required this.onSubcategorySelected,
  });

  final TransactionType type;
  final String? selectedCategory;
  final String? selectedSubcategory;
  final Color accentColor;
  final Color accentLight;
  final List<TransactionCategory> customCats;
  final VoidCallback onCategoryTap;
  final ValueChanged<String> onSubcategorySelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCompactRow(
          emoji: selectedCategory != null
              ? TransactionCategories.resolveEmoji(
                  selectedCategory!, type.isIncome, customCats)
              : null,
          icon: selectedCategory == null ? Icons.category_outlined : null,
          label: selectedCategory != null
              ? TransactionCategories.localizedName(selectedCategory!, l10n)
              : l10n.category,
          hasValue: selectedCategory != null,
          accent: accentColor,
          accentLight: accentLight,
          onTap: onCategoryTap,
          semanticLabel:
              '${l10n.category}: ${selectedCategory != null ? TransactionCategories.localizedName(selectedCategory!, l10n) : l10n.tutorialSkip}',
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: selectedCategory != null
              ? Padding(
                  padding: const EdgeInsets.only(
                      top: AppSpacing.sm, left: AppSpacing.xl),
                  child: AppCompactRow(
                    icon: selectedSubcategory == null
                        ? Icons.label_outline_rounded
                        : null,
                    emoji: selectedSubcategory != null ? '🏷' : null,
                    label: selectedSubcategory ?? l10n.subcategory,
                    hasValue: selectedSubcategory != null,
                    accent: accentColor,
                    accentLight: accentLight,
                    onTap: () async {
                      final sub = await showModalBottomSheet<String>(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        builder: (_) => _SubcategoryPickerSheet(
                          selected: selectedSubcategory,
                          category: selectedCategory!,
                          type: type,
                          accentColor: accentColor,
                          accentLight: accentLight,
                        ),
                      );
                      if (sub != null) onSubcategorySelected(sub);
                    },
                    semanticLabel:
                        '${l10n.subcategory}: ${selectedSubcategory ?? ""}',
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ── Details block: descripción con label visible ───────────────────────────────

class _DetailsBlock extends StatelessWidget {
  const _DetailsBlock({
    required this.descriptionController,
    required this.descriptionFocus,
  });

  final TextEditingController descriptionController;
  final FocusNode descriptionFocus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = context.colors;
    return AppCard(
      variant: AppCardVariant.outlined,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.edit_note_rounded,
              size: 18, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextFormField(
              controller: descriptionController,
              focusNode: descriptionFocus,
              maxLines: 1,
              maxLength: 100,
              textInputAction: TextInputAction.done,
              onTapOutside: (_) => descriptionFocus.unfocus(),
              onEditingComplete: descriptionFocus.unfocus,
              style: TextStyle(
                fontFamily: 'GeneralSans',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: l10n.descriptionOptional,
                hintStyle: const TextStyle(
                  fontFamily: 'GeneralSans',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textTertiary,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.sm),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Subcategory picker sheet ──────────────────────────────────────────────────

class _SubcategoryPickerSheet extends ConsumerWidget {
  const _SubcategoryPickerSheet({
    required this.selected,
    required this.category,
    required this.type,
    required this.accentColor,
    required this.accentLight,
  });

  final String? selected;
  final String category;
  final TransactionType type;
  final Color accentColor;
  final Color accentLight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cs = context.colors;
    final asyncSubs = ref.watch(
      subcategoriesProvider((category: category, type: type)),
    );
    final subcategories = asyncSubs.value ?? [];

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Row(
              children: [
                Text(
                  l10n.subcategory.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'GeneralSans',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: AppColors.textMuted,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    l10n.tutorialSkip,
                    style: TextStyle(color: accentColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                ...subcategories.map((name) {
                  final isSelected = selected == name;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.only(
                        left: 14, top: 4, bottom: 4, right: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? accentLight : cs.surface,
                      borderRadius: AppRadius.radiusPill,
                      border: Border.all(
                        color:
                            isSelected ? accentColor : AppColors.borderLight,
                        width: 1.5,
                      ),
                      boxShadow:
                          isSelected ? null : AppColors.softShadowSm,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.pop(context, name);
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              name,
                              style: TextStyle(
                                fontFamily: 'GeneralSans',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? accentColor
                                    : AppColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs + 2),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.heavyImpact();
                            _confirmDeleteSubcategory(context, ref, name);
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (isSelected
                                      ? accentColor
                                      : AppColors.textMuted)
                                  .withValues(alpha: 0.12),
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 12,
                              color: isSelected
                                  ? accentColor
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                GestureDetector(
                  onTap: () async {
                    final newName = await showDialog<String>(
                      context: context,
                      builder: (_) => CreateSubcategoryDialog(
                        category: category,
                        type: type,
                      ),
                    );
                    if (newName != null && context.mounted) {
                      Navigator.pop(context, newName);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: AppRadius.radiusPill,
                      border: Border.all(
                        color: AppColors.dustyTeal,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_rounded,
                            size: 14, color: AppColors.dustyTeal),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          l10n.newSubcategory,
                          style: const TextStyle(
                            fontFamily: 'GeneralSans',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.dustyTeal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteSubcategory(
    BuildContext context,
    WidgetRef ref,
    String name,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.deleteSubcategoryConfirm),
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
    if (confirmed != true || !context.mounted) return;
    await ref
        .read(subcategoriesRepositoryProvider)
        .remove(category, type, name);
    ref.invalidate(
      subcategoriesProvider((category: category, type: type)),
    );
  }
}

// ── Step indicator (two segmented capsule bars) ──────────────────────────────

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({
    required this.currentStep,
    required this.accent,
  });

  final int currentStep;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _Bar(active: true, accent: accent)),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: _Bar(active: currentStep >= 1, accent: accent)),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.active, required this.accent});

  final bool active;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      height: 4,
      decoration: BoxDecoration(
        color: active ? accent : AppColors.borderLight,
        borderRadius: AppRadius.radiusPill,
      ),
    );
  }
}

// ── Amount pill (AppBar action in step 2) ─────────────────────────────────────

class _AmountPill extends StatelessWidget {
  const _AmountPill({
    required this.controller,
    required this.type,
    required this.accent,
    required this.accentLight,
    required this.currencyCode,
    required this.onTap,
  });

  final AmountKeypadController controller;
  final TransactionType type;
  final Color accent;
  final Color accentLight;
  final String currencyCode;
  final VoidCallback onTap;

  String _format(double v) {
    if (v == v.truncateToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2).replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final value = controller.resolve() ?? 0;
        final amountStr = _format(value);
        final icon = type.isIncome
            ? Icons.trending_up_rounded
            : Icons.trending_down_rounded;
        return Semantics(
          button: true,
          label: '${type.isIncome ? "+" : "-"}$amountStr $currencyCode',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: AppRadius.radiusPill,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accentLight,
                  borderRadius: AppRadius.radiusPill,
                  border: Border.all(
                    color: accent.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: accent),
                    const SizedBox(width: 4),
                    Text(
                      '${currencySymbol(currencyCode)} $amountStr',
                      style: TextStyle(
                        fontFamily: 'GeneralSans',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.edit_rounded,
                      size: 11,
                      color: accent.withValues(alpha: 0.65),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── AI shortcuts row (voice + photo buttons in step 1) ──────────────────────

class _AiShortcutsRow extends StatelessWidget {
  const _AiShortcutsRow({
    required this.voiceLabel,
    required this.photoLabel,
    required this.disabled,
    required this.onVoiceTap,
    required this.onPhotoTap,
  });

  final String voiceLabel;
  final String photoLabel;
  final bool disabled;
  final VoidCallback onVoiceTap;
  final VoidCallback onPhotoTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _AiShortcutButton(
            icon: Icons.mic_rounded,
            label: voiceLabel,
            disabled: disabled,
            onTap: onVoiceTap,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _AiShortcutButton(
            icon: Icons.camera_alt_outlined,
            label: photoLabel,
            disabled: disabled,
            onTap: onPhotoTap,
          ),
        ),
      ],
    );
  }
}

class _AiShortcutButton extends StatelessWidget {
  const _AiShortcutButton({
    required this.icon,
    required this.label,
    required this.disabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.dustyTeal;
    final bg = AppColors.dustyTealLight;
    final opacity = disabled ? 0.45 : 1.0;
    return Opacity(
      opacity: opacity,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: disabled ? null : onTap,
            borderRadius: AppRadius.radiusMd,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.md),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: AppRadius.radiusMd,
                border: Border.all(
                  color: color.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: color),
                  const SizedBox(width: AppSpacing.xs + 2),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'GeneralSans',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: color,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Capture overlay (voice listening / AI processing) ────────────────────────

class _CaptureOverlay extends StatelessWidget {
  const _CaptureOverlay({required this.state, required this.onStop});

  final _CaptureState state;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isListening = state == _CaptureState.listening;
    final label = switch (state) {
      _CaptureState.listening => l10n.voiceListening,
      _CaptureState.voiceProcessing => l10n.voiceProcessing,
      _CaptureState.imageProcessing => l10n.imageProcessing,
      _CaptureState.idle => '',
    };

    return Positioned.fill(
      child: Semantics(
        liveRegion: true,
        label: label,
        child: GestureDetector(
          onTap: isListening ? onStop : null,
          behavior: HitTestBehavior.opaque,
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.45),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isListening)
                    GestureDetector(
                      onTap: onStop,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.stop_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: AppColors.dustyTeal,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.8,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'GeneralSans',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
