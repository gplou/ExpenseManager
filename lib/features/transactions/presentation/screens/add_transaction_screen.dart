import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:expense_manager/core/config/router.dart';
import 'package:expense_manager/core/constants/test_keys.dart';
import 'package:expense_manager/core/errors/failure_localizations.dart';
import 'package:expense_manager/core/errors/failures.dart';
import 'package:expense_manager/core/providers/currency_provider.dart';
import 'package:expense_manager/core/services/image_input_gateway.dart';
import 'package:expense_manager/core/services/sentry_service.dart';
import 'package:expense_manager/core/theme/app_colors.dart';
import 'package:expense_manager/core/theme/app_spacing.dart';
import 'package:expense_manager/core/utils/extensions.dart';
import 'package:expense_manager/core/widgets/ad_banner_footer.dart';
import 'package:expense_manager/core/widgets/numeric_keypad.dart';
import 'package:expense_manager/l10n/app_localizations.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/features/transactions/data/image_transaction_parser.dart';
import 'package:expense_manager/features/transactions/data/recurring_transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/subcategories_repository.dart';
import 'package:expense_manager/features/transactions/domain/parsed_voice_transaction.dart';
import 'package:expense_manager/features/transactions/domain/recurring_transaction_model.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/presentation/providers/subcategories_provider.dart';
import 'package:expense_manager/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:expense_manager/features/transactions/presentation/providers/voice_capture_provider.dart';
import 'package:expense_manager/features/transactions/presentation/widgets/add_transaction_widgets.dart';
import 'package:expense_manager/features/transactions/presentation/widgets/category_picker_sheet.dart';
import 'package:expense_manager/features/transactions/presentation/widgets/recent_categories_strip.dart';

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

/// Pantalla única de entrada rápida.
///
/// Todo lo necesario para el caso común vive en una sola vista sin pasos:
/// teclear importe → tocar un chip de categoría → pulsar ✓ en el keypad.
/// Fecha, nota, subcategoría y recurrencia son píldoras con disclosure
/// progresivo (abren sheets compactos) para no penalizar la velocidad.
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
  late final ImageInputGateway _imageGateway;
  late final VoiceCaptureNotifier _voiceCapture;
  String _note = '';
  String? _selectedCategory;
  String? _selectedSubcategory;
  late DateTime _selectedDate;
  bool _isSaving = false;
  bool _isListening = false;
  bool _isCapturing = false;

  /// null = no repetir. Un valor activo marca la transacción como recurrente.
  RecurrenceType? _recurrenceType;
  String? _amountError;

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    final v = widget.voiceData;
    _type = t?.type ?? v?.type ?? TransactionType.expense;
    _keypadController = AmountKeypadController();
    _imageGateway = ref.read(imageInputGatewayProvider);
    // Captured once: `ref.read` is unsafe from dispose() once the widget is
    // being unmounted, so the notifier reference is stored instead.
    _voiceCapture = ref.read(voiceCaptureProvider.notifier);
    final initialAmount = t?.amount ?? v?.amount;
    if (initialAmount != null && initialAmount > 0) {
      _keypadController.setValue(initialAmount);
    }
    _note = t?.description ?? v?.description ?? '';
    _selectedCategory = t?.category ?? v?.category;
    _selectedSubcategory = t?.subcategory ?? v?.subcategory;
    _selectedDate = t?.date ?? v?.date ?? clock.now();

    if (v?.isRecurring == true) {
      _recurrenceType = switch (v?.recurrenceType) {
        'weekly' => RecurrenceType.weekly,
        'annual' => RecurrenceType.annual,
        _ => RecurrenceType.monthly,
      };
    }
    if (v?.subcategory != null && v?.category != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _ensureSubcategoryExists(v!));
    }
    if (t?.recurringTransactionId != null) {
      _recurrenceType = RecurrenceType.monthly;
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

  /// Applies a voice/photo parse result onto the current form fields —
  /// shared by the initial [widget.voiceData] (widget-triggered capture)
  /// and the in-screen mic/camera buttons, so both paths behave identically.
  void _applyParsedTransaction(ParsedVoiceTransaction v) {
    setState(() {
      _type = v.type;
      if (v.amount > 0) _keypadController.setValue(v.amount);
      if (v.description != null) _note = v.description!;
      _selectedCategory = v.category;
      _selectedSubcategory = v.subcategory;
      if (v.date != null) _selectedDate = v.date!;
      _recurrenceType = v.isRecurring
          ? switch (v.recurrenceType) {
              'weekly' => RecurrenceType.weekly,
              'annual' => RecurrenceType.annual,
              _ => RecurrenceType.monthly,
            }
          : null;
    });
    if (v.subcategory != null) _ensureSubcategoryExists(v);
  }

  Future<void> _ensureSubcategoryExists(ParsedVoiceTransaction v) async {
    if (!mounted || v.subcategory == null) return;
    try {
      final repo = ref.read(subcategoriesRepositoryProvider);
      final existing = await repo.getForCategory(v.category, v.type);
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
  }

  bool _requirePro() {
    if (ref.read(isProProvider)) return true;
    context.push(AppRoutes.pro);
    return false;
  }

  Timer? _voiceMaxDurationTimer;

  Future<void> _onTapVoice() async {
    if (_isListening) {
      await _stopAndProcessVoice();
      return;
    }
    if (!_requirePro()) return;

    final l10n = AppLocalizations.of(context);
    final started = await _voiceCapture.start(
      onSilenceTimeout: () {
        if (_isListening) _stopAndProcessVoice();
      },
    );
    if (!mounted) return;
    if (!started) {
      context.showSnackbar(l10n.micUnavailable, isError: true);
      return;
    }
    setState(() => _isListening = true);
    _voiceMaxDurationTimer?.cancel();
    _voiceMaxDurationTimer = Timer(VoiceCaptureNotifier.maxDuration, () {
      if (_isListening) _stopAndProcessVoice();
    });
  }

  Future<void> _stopAndProcessVoice() async {
    _voiceMaxDurationTimer?.cancel();
    setState(() {
      _isListening = false;
      _isCapturing = true;
    });
    final l10n = AppLocalizations.of(context);
    try {
      final subcats = ref.read(allSubcategoriesProvider).value ?? const [];
      final parsed =
          await _voiceCapture.stopAndProcess(subcategories: subcats);
      if (!mounted) return;
      if (parsed == null) {
        context.showSnackbar(l10n.voiceInterpretError, isError: true);
      } else {
        _applyParsedTransaction(parsed);
      }
    } on AppFailure catch (f) {
      if (mounted) context.showSnackbar(f.localizedMessage(l10n), isError: true);
    } catch (e, st) {
      unawaited(SentryService.captureException(e, stackTrace: st));
      if (mounted) context.showSnackbar(l10n.aiProcessingError, isError: true);
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _onTapPhoto() async {
    if (!_requirePro()) return;
    final l10n = AppLocalizations.of(context);

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        final sheetL10n = AppLocalizations.of(sheetCtx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(PhosphorIcons.camera),
                  title: Text(sheetL10n.cameraOption),
                  onTap: () => Navigator.of(sheetCtx).pop(ImageSource.camera),
                ),
                ListTile(
                  leading: Icon(PhosphorIcons.imagesSquare),
                  title: Text(sheetL10n.galleryOption),
                  onTap: () => Navigator.of(sheetCtx).pop(ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (source == null || !mounted) return;

    final picked = await _imageGateway.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _isCapturing = true);
    File? tempFile;
    try {
      tempFile = File(picked.path);
      final parsed =
          await ref.read(imageTransactionParserProvider).parse(picked.path);
      if (!mounted) return;
      if (parsed == null) {
        context.showSnackbar(l10n.imageTransactionNotDetected, isError: true);
      } else {
        _applyParsedTransaction(parsed);
      }
    } catch (e, st) {
      unawaited(SentryService.captureException(e, stackTrace: st));
      if (mounted) context.showSnackbar(l10n.aiProcessingError, isError: true);
    } finally {
      try {
        if (tempFile != null && await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  void dispose() {
    _keypadController.dispose();
    _voiceMaxDurationTimer?.cancel();
    // Only cancels if this screen's own recording is still active — a
    // no-op if a different voice entry point owns the current capture.
    if (_isListening) _voiceCapture.cancelIfRecording();
    super.dispose();
  }

  Color get _accentColor =>
      _type.isIncome ? AppColors.sageGreen : AppColors.mutedTerra;
  Color get _accentLight =>
      _type.isIncome ? AppColors.sageGreenLight : AppColors.mutedTerraLight;

  Future<void> _openCategoryPicker() async {
    final selected = await showCategoryPickerSheet(
      context,
      ref,
      type: _type,
      selectedCategory: _selectedCategory,
      accentColor: _accentColor,
      accentLight: _accentLight,
    );
    if (selected != null && mounted) {
      setState(() {
        _selectedCategory = selected;
        _selectedSubcategory = null;
      });
    }
  }

  Future<void> _openSubcategoryPicker() async {
    final sub = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SubcategoryPickerSheet(
        selected: _selectedSubcategory,
        category: _selectedCategory!,
        type: _type,
        accentColor: _accentColor,
        accentLight: _accentLight,
      ),
    );
    if (sub != null && mounted) {
      setState(() => _selectedSubcategory = sub);
    }
  }

  Future<void> _pickDate() async {
    final date = await showQuickDateSheet(
      context,
      selected: _selectedDate,
      accent: _accentColor,
    );
    if (date != null && mounted) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _editNote() async {
    final note = await showNoteSheet(
      context,
      initial: _note,
      accent: _accentColor,
    );
    if (note != null && mounted) {
      setState(() => _note = note);
    }
  }

  Future<void> _pickRecurrence() async {
    final choice = await showRecurrenceSheet(
      context,
      current: _recurrenceType,
      date: _selectedDate,
      accent: _accentColor,
    );
    if (choice != null && mounted) {
      setState(() => _recurrenceType = choice.type);
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
      HapticFeedback.heavyImpact().ignore();
      context.showSnackbar(l10n.selectCategory, isError: true);
      return;
    }

    final desc = _note.trim().isEmpty ? null : _note.trim();

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
            isRecurring: _recurrenceType != null,
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
    final isPro = ref.watch(isProProvider);
    final currencyCode = ref.watch(currencyProvider).value ?? 'EUR';

    final saveLabel = _isEditing
        ? l10n.saveChanges
        : (_type.isIncome ? l10n.saveIncome : l10n.saveExpense);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(_isEditing ? l10n.editTransaction : l10n.newTransaction),
        actions: [
          if (!_isEditing) ...[
            IconButton(
              tooltip: l10n.labelVoice,
              onPressed: _isCapturing ? null : _onTapVoice,
              icon: _isListening
                  ? Icon(PhosphorIcons.stop, color: AppColors.mutedTerra)
                  : Icon(PhosphorIcons.microphone),
            ),
            IconButton(
              tooltip: l10n.labelPhoto,
              onPressed:
                  (_isListening || _isCapturing) ? null : _onTapPhoto,
              icon: Icon(PhosphorIcons.camera),
            ),
          ],
          if (_isEditing)
            IconButton(
              key: TestKeys.transactionDeleteButton,
              tooltip: l10n.delete,
              onPressed: _delete,
              icon: Icon(
                PhosphorIcons.trash,
                color: AppColors.mutedTerra,
              ),
            ),
        ],
      ),
      bottomNavigationBar:
          isPro ? null : const SafeArea(top: false, child: AdBannerFooter()),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, 0),
          child: Column(
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
                accent: _accentColor,
                currencyCode: currencyCode,
                error: _amountError,
              ),
              const SizedBox(height: AppSpacing.sm),
              QuickCategoryStrip(
                type: _type,
                selected: _selectedCategory,
                accentColor: _accentColor,
                accentLight: _accentLight,
                onMore: _openCategoryPicker,
                onSelect: (cat) {
                  setState(() {
                    if (_selectedCategory != cat) {
                      _selectedCategory = cat;
                      _selectedSubcategory = null;
                    }
                  });
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildDetailPills(l10n),
              Expanded(
                child: NumericKeypad(
                  controller: _keypadController,
                  accent: _accentColor,
                  submitLabel: saveLabel,
                  canSubmit: !_isSaving,
                  onSubmit: _save,
                  fillVertical: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailPills(AppLocalizations l10n) {
    final dateLabel = relativeDateLabel(context, _selectedDate);
    final isToday = dateLabel == l10n.relToday;
    final recurrenceLabel = switch (_recurrenceType) {
      RecurrenceType.weekly => l10n.weekly,
      RecurrenceType.monthly => l10n.monthly,
      RecurrenceType.annual => l10n.yearly,
      null => l10n.noRepeat,
    };

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        children: [
          DetailPill(
            icon: PhosphorIcons.calendar,
            label: dateLabel,
            active: !isToday,
            accent: _accentColor,
            accentLight: _accentLight,
            semanticLabel: '${l10n.date}: $dateLabel',
            onTap: _pickDate,
          ),
          if (_selectedCategory != null) ...[
            const SizedBox(width: AppSpacing.sm),
            DetailPill(
              icon: PhosphorIcons.tag,
              label: _selectedSubcategory ?? l10n.subcategory,
              active: _selectedSubcategory != null,
              accent: _accentColor,
              accentLight: _accentLight,
              semanticLabel:
                  '${l10n.subcategory}: ${_selectedSubcategory ?? ""}',
              onTap: _openSubcategoryPicker,
            ),
          ],
          const SizedBox(width: AppSpacing.sm),
          DetailPill(
            key: TestKeys.transactionNotePill,
            icon: PhosphorIcons.notePencil,
            label: _note.trim().isEmpty ? l10n.note : _note.trim(),
            active: _note.trim().isNotEmpty,
            accent: _accentColor,
            accentLight: _accentLight,
            semanticLabel: '${l10n.note}: ${_note.trim()}',
            onTap: _editNote,
          ),
          const SizedBox(width: AppSpacing.sm),
          DetailPill(
            icon: PhosphorIcons.repeat,
            label: recurrenceLabel,
            active: _recurrenceType != null,
            accent: _accentColor,
            accentLight: _accentLight,
            semanticLabel: '${l10n.recurringTransaction}: $recurrenceLabel',
            onTap: _pickRecurrence,
          ),
        ],
      ),
    );
  }
}
