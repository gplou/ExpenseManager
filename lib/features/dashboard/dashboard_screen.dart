import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/config/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/extensions.dart';
import '../../core/widgets/custom_date_range_picker.dart';
import '../../core/widgets/neo_card.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/app_drawer.dart';
import 'widgets/category_distribution_sheet.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../transactions/data/voice_transaction_parser.dart';
import '../transactions/data/image_transaction_parser.dart';
import '../transactions/domain/parsed_voice_transaction.dart';
import '../auth/presentation/providers/auth_provider.dart';
import '../transactions/domain/transaction_categories.dart';
import '../transactions/domain/transaction_model.dart';
import '../transactions/domain/transactions_repository_contract.dart';
import '../transactions/presentation/providers/custom_categories_provider.dart';
import '../transactions/presentation/providers/recurring_transactions_provider.dart';
import '../transactions/presentation/providers/transactions_provider.dart';
import '../transactions/presentation/screens/add_transaction_screen.dart';
import '../transactions/data/subcategories_repository.dart';
import '../transactions/presentation/providers/subcategories_provider.dart';
import '../subscription/subscription_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(subscriptionProvider.notifier).forceRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(processRecurringTransactionsProvider);

    final l10n = AppLocalizations.of(context);
    final user = ref.watch(currentUserProvider);
    final period = ref.watch(selectedPeriodProvider);
    final customRange = ref.watch(customDateRangeProvider);
    final summaryAsync = ref.watch(transactionsSummaryProvider);
    final recentAsync = ref.watch(recentTransactionsProvider);
    final cs = context.colors;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.greeting(
                user?.name?.split(' ').first ?? l10n.defaultUser,
              ),
              style: context.textTheme.titleLarge,
            ),
            Text(
              DateTime.now().formattedDate,
              style: TextStyle(
                fontFamily: 'Sora',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: cs.onSurface.withValues(alpha: 0.38),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
        color: AppColors.dustyTeal,
        backgroundColor: cs.surface,
        onRefresh: () async {
          ref.invalidate(processRecurringTransactionsProvider);
          ref.invalidate(transactionsSummaryProvider);
          ref.invalidate(recentTransactionsProvider);
          await ref.read(subscriptionProvider.notifier).forceRefresh();
        },
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Selector de período ──────────────────────────────────────
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ...TransactionPeriod.values.map((p) {
                            final isSelected = p == period && customRange == null;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _PeriodChip(
                                label: p.l10nLabel(l10n),
                                isSelected: isSelected,
                                onTap: () {
                                  ref.read(selectedPeriodProvider.notifier).state = p;
                                  ref.read(customDateRangeProvider.notifier).state = null;
                                },
                              ),
                            );
                          }),
                          _IconChip(
                            icon: Icons.calendar_month_outlined,
                            isActive: customRange != null,
                            onTap: () async {
                              final range = await showCustomDateRangePicker(
                                context: context,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                                initialDateRange: customRange ??
                                    DateTimeRange(
                                      start: period.dateRange.from,
                                      end: period.dateRange.to,
                                    ),
                              );
                              if (range != null) {
                                ref.read(customDateRangeProvider.notifier).state = range;
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const Gap(12),

                    // ── Balance principal ────────────────────────────────────────
                    summaryAsync.when(
                      loading: () => const _SummaryShimmer(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (summary) => _SummarySection(summary: summary),
                    ),
                    const Gap(12),

                    // ── Transacciones recientes ──────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.recent.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'Sora',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface.withValues(alpha: 0.4),
                            letterSpacing: 1.5,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.push(AppRoutes.transactions),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.dustyTealLight,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              l10n.seeAll,
                              style: const TextStyle(
                                fontFamily: 'Sora',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.dustyTeal,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Gap(8),
                    recentAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(color: AppColors.dustyTeal),
                      ),
                      error: (e, _) => Text(e.toString()),
                      data: (transactions) {
                        if (transactions.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('📭', style: TextStyle(fontSize: 40)),
                                const Gap(8),
                                Text(
                                  l10n.noTransactionsPeriod,
                                  style: TextStyle(
                                    fontFamily: 'Sora',
                                    fontSize: 14,
                                    color: cs.onSurface.withValues(alpha: 0.4),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return Column(
                          children: transactions
                              .map((t) => _RecentTransactionTile(transaction: t))
                              .toList(),
                        );
                      },
                    ),

                  ],
                ),
                  ),
            const Gap(12),

            // ── Banner de anuncio (oculto para usuarios PRO) ────────────
            Consumer(
              builder: (context, ref, _) {
                if (ref.watch(isProProvider)) return const SizedBox.shrink();
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: _AdBanner(),
                );
              },
            ),
            const Gap(12),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 80),
          ],
        ),
      ),
    ),
  ),
      ),
          // ── Speed dial overlay (backdrop + radial buttons) ─────────────
          const Positioned.fill(
            child: _SpeedDialFab(),
          ),
        ],
      ),
    );
  }
}

// ── Period chip ───────────────────────────────────────────────────────────────

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.dustyTeal : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected ? AppColors.dustyTeal : AppColors.borderMedium,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Sora',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? AppColors.pureWhite
                : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.warmAmberLight : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isActive ? AppColors.warmAmber : AppColors.borderMedium,
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isActive ? AppColors.warmAmber : AppColors.textMuted,
        ),
      ),
    );
  }
}

// ── Summary section ───────────────────────────────────────────────────────────

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.summary});
  final TransactionsSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final balance = summary.balance;
    final isPositive = balance >= 0;
    final accentColor = isPositive ? AppColors.sageGreen : AppColors.mutedTerra;
    final accentLight = isPositive ? AppColors.sageGreenLight : AppColors.mutedTerraLight;

    return Column(
      children: [
        // Balance card principal
        NeoCard(
          accentColor: accentColor,
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentLight,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      l10n.balance.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Sora',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: accentColor,
                      ),
                    ),
                  ),
                ],
              ),
              const Gap(12),
              Text(
                '${isPositive ? '' : '-'}€${balance.abs().toStringAsFixed(2)}',
                style: context.textTheme.displaySmall?.copyWith(
                  color: context.colors.onSurface,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const Gap(4),
              Text(
                isPositive ? '📈' : '📉',
                style: const TextStyle(fontSize: 18),
              ),
            ],
          ),
        ),
        const Gap(12),
        // Mini cards Ingresos / Gastos
        Row(
          children: [
            Expanded(
              child: _MiniCard(
                label: l10n.income,
                amount: summary.income,
                accentColor: AppColors.sageGreen,
                accentLight: AppColors.sageGreenLight,
                icon: Icons.arrow_downward_rounded,
                onTap: () => showCategoryDistributionSheet(
                  context,
                  TransactionType.income,
                ),
              ),
            ),
            const Gap(12),
            Expanded(
              child: _MiniCard(
                label: l10n.expenses,
                amount: summary.expense,
                accentColor: AppColors.mutedTerra,
                accentLight: AppColors.mutedTerraLight,
                icon: Icons.arrow_upward_rounded,
                onTap: () => showCategoryDistributionSheet(
                  context,
                  TransactionType.expense,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.label,
    required this.amount,
    required this.accentColor,
    required this.accentLight,
    required this.icon,
    this.onTap,
  });

  final String label;
  final double amount;
  final Color accentColor;
  final Color accentLight;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return NeoCard(
      accentColor: accentColor,
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accentLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 18),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
                const Gap(2),
                Text(
                  '€${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shimmer placeholder ───────────────────────────────────────────────────────

class _SummaryShimmer extends StatelessWidget {
  const _SummaryShimmer();

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 140,
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppColors.softShadow,
          ),
        ),
        const Gap(12),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppColors.softShadow,
                ),
              ),
            ),
            const Gap(12),
            Expanded(
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppColors.softShadow,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Recent transaction tile ───────────────────────────────────────────────────

class _RecentTransactionTile extends ConsumerWidget {
  const _RecentTransactionTile({required this.transaction});
  final TransactionModel transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cs = context.colors;
    final isIncome = transaction.type.isIncome;
    final accentColor = isIncome ? AppColors.sageGreen : AppColors.mutedTerra;
    final accentLight = isIncome ? AppColors.sageGreenLight : AppColors.mutedTerraLight;
    final emoji = _emojiForCategory(transaction.category, isIncome);
    final customCats = ref.watch(customCategoriesSyncProvider)[transaction.type] ?? const [];
    IconData? customIcon;
    for (final c in customCats) {
      if (c.name == transaction.category) { customIcon = c.icon; break; }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AddTransactionScreen(transaction: transaction),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppColors.softShadowSm,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accentLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: customIcon != null
                        ? Icon(customIcon, size: 22, color: accentColor)
                        : Text(emoji, style: const TextStyle(fontSize: 22)),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        TransactionCategories.localizedName(transaction.category, l10n),
                        style: TextStyle(
                          fontFamily: 'Sora',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      if (transaction.subcategory != null)
                        Text(
                          transaction.subcategory!,
                          style: const TextStyle(
                            fontFamily: 'Sora',
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      else if (transaction.description != null)
                        Text(
                          transaction.description!,
                          style: const TextStyle(
                            fontFamily: 'Sora',
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      else
                        Text(
                          transaction.date.formattedDate,
                          style: const TextStyle(
                            fontFamily: 'Sora',
                            fontSize: 12,
                            color: AppColors.textSubtle,
                          ),
                        ),
                    ],
                  ),
                ),
                const Gap(8),
                Text(
                  '${isIncome ? '+' : '-'}€${transaction.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _emojiForCategory(String category, bool isIncome) => switch (category) {
    'Salario'    => '💼',
    'Freelance'  => '💻',
    'Inversión'  => '📈',
    'Regalo'     => '🎁',
    'Comida'     => '🍕',
    'Transporte' => '🚗',
    'Vivienda'   => '🏠',
    'Ocio'       => '🎮',
    'Salud'      => '💊',
    'Educación'  => '📚',
    'Ropa'       => '👕',
    'Tecnología' => '⚡',
    _            => isIncome ? '💰' : '💸',
  };
}

// ── Ad banner placeholder ─────────────────────────────────────────────────────

class _AdBanner extends StatelessWidget {
  const _AdBanner();

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Container(
      width: double.infinity,
      height: 90,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.borderLight,
          width: 1,
        ),
        boxShadow: AppColors.softShadowSm,
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.campaign_outlined,
            size: 18,
            color: AppColors.textSubtle,
          ),
          SizedBox(width: 8),
          Text(
            'Publicidad',
            style: TextStyle(
              fontFamily: 'Sora',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSubtle,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Speed dial FAB ────────────────────────────────────────────────────────────

enum _VoiceInputState { idle, listening, processing, cameraProcessing }

class _SpeedDialFab extends ConsumerStatefulWidget {
  const _SpeedDialFab();

  @override
  ConsumerState<_SpeedDialFab> createState() => _SpeedDialFabState();
}

class _SpeedDialFabState extends ConsumerState<_SpeedDialFab> {
  bool _open = false;
  _VoiceInputState _voiceState = _VoiceInputState.idle;

  final _speech = SpeechToText();
  final _parser = VoiceTransactionParser();
  final _imagePicker = ImagePicker();
  final _imageParser = ImageTransactionParser();

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  void _toggle() => setState(() => _open = !_open);

  void _closeDial() {
    if (_open) setState(() => _open = false);
  }

  Future<void> _startVoice() async {
    _closeDial();

    final available = await _speech.initialize(
      onError: (_) {
        if (mounted) setState(() => _voiceState = _VoiceInputState.idle);
      },
    );

    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Micrófono no disponible')),
        );
      }
      return;
    }

    setState(() => _voiceState = _VoiceInputState.listening);

    await _speech.listen(
      localeId: 'es_ES',
      onResult: (result) {
        if (result.finalResult) _processVoice(result.recognizedWords);
      },
    );
  }

  Future<void> _processVoice(String text) async {
    if (text.trim().isEmpty) {
      if (mounted) setState(() => _voiceState = _VoiceInputState.idle);
      return;
    }
    setState(() => _voiceState = _VoiceInputState.processing);
    ParsedVoiceTransaction? parsed;
    try {
      parsed = await _parser.parse(text);
    } catch (e) {
      if (!mounted) return;
      setState(() => _voiceState = _VoiceInputState.idle);
      final info = e.toString().split('\n').first;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error IA voz [${e.runtimeType}]: $info')),
      );
      return;
    }
    if (!mounted) return;
    if (parsed == null) {
      setState(() => _voiceState = _VoiceInputState.idle);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo interpretar. Inténtalo de nuevo.'),
        ),
      );
      return;
    }
    // Save directly without navigating to verification screen
    try {
      // Auto-create new subcategory if the AI suggested one
      if (parsed.isNewSubcategory && parsed.subcategory != null) {
        await ref.read(subcategoriesRepositoryProvider).add(
              parsed.category,
              parsed.type,
              parsed.subcategory!,
            );
        ref.invalidate(subcategoriesProvider(
          (category: parsed.category, type: parsed.type),
        ));
      }
      final transaction = TransactionModel(
        id: '',
        userId: '',
        amount: parsed.amount,
        type: parsed.type,
        category: parsed.category,
        subcategory: parsed.subcategory,
        description: parsed.description,
        date: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await ref
          .read(transactionsNotifierProvider.notifier)
          .create(transaction);
      if (!mounted) return;
      setState(() => _voiceState = _VoiceInputState.idle);
      final l10n = AppLocalizations.of(context);
      final catName = TransactionCategories.localizedName(parsed.category, l10n);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${parsed.type == TransactionType.income ? '+' : '-'}€${parsed.amount.toStringAsFixed(2)} · $catName',
          ),
          backgroundColor: AppColors.dustyTeal,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _voiceState = _VoiceInputState.idle);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: ${e.toString().split('\n').first}')),
      );
    }
  }

  Future<void> _startCamera() async {
    _closeDial();

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Cámara'),
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Galería'),
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null || !mounted) return;

    final XFile? picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (picked == null || !mounted) return;
    await _processImage(picked);
  }

  Future<void> _processImage(XFile pickedFile) async {
    if (!mounted) return;
    setState(() => _voiceState = _VoiceInputState.cameraProcessing);

    File? tempFile;
    try {
      tempFile = File(pickedFile.path);
      final imageBytes = await tempFile.readAsBytes();

      final ParsedVoiceTransaction? parsed = await _imageParser.parse(imageBytes);

      if (!mounted) return;
      setState(() => _voiceState = _VoiceInputState.idle);

      if (parsed == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo detectar una transacción en la imagen.'),
          ),
        );
        return;
      }
      // Auto-create new subcategory if the AI suggested one
      if (parsed.isNewSubcategory && parsed.subcategory != null) {
        await ref.read(subcategoriesRepositoryProvider).add(
              parsed.category,
              parsed.type,
              parsed.subcategory!,
            );
        ref.invalidate(subcategoriesProvider(
          (category: parsed.category, type: parsed.type),
        ));
      }
      // Save directly without navigating to verification screen
      final transaction = TransactionModel(
        id: '',
        userId: '',
        amount: parsed.amount,
        type: parsed.type,
        category: parsed.category,
        subcategory: parsed.subcategory,
        description: parsed.description,
        date: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await ref
          .read(transactionsNotifierProvider.notifier)
          .create(transaction);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final catName = TransactionCategories.localizedName(parsed.category, l10n);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${parsed.type == TransactionType.income ? '+' : '-'}€${parsed.amount.toStringAsFixed(2)} · $catName',
          ),
          backgroundColor: AppColors.dustyTeal,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _voiceState = _VoiceInputState.idle);
        final info = e.toString().split('\n').first;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error IA imagen [${e.runtimeType}]: $info')),
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

  // ── Layout constants ──────────────────────────────────────────────────────
  //
  //  Stack size: 220 × 175 px
  //  FAB (64 px) → bottom-centre of the Stack: centre at (110, 143)
  //  Mini buttons (50 px) on a circle of r = 85 px, ±65° and 0° from straight-up:
  //
  //           [🎤]   [✏️]   [📷]
  //             \     |     /
  //              \    |    /    ← r = 85 px
  //               \   |   /
  //                  [+]
  //
  //  Mic    → centre (33, 107)  = FAB centre + (−77, −36)
  //  Pencil → centre (110, 58)  = FAB centre + (  0, −85)
  //  Camera → centre (187, 107) = FAB centre + (+77, −36)
  static const double _stackW   = 220;
  static const double _stackH   = 175;
  static const double _fabSize  =  64;
  static const double _miniSize =  50;

  // FAB centre inside the Stack (Stack coords: origin = top-left)
  static const double _fabCx = _stackW / 2;             // 110
  static const double _fabCy = _stackH - _fabSize / 2;  // 143

  // Mini-button target centres when open
  static const Offset _micTarget    = Offset(33,  107);
  static const Offset _pencilTarget = Offset(110,  58);
  static const Offset _cameraTarget = Offset(187, 107);

  // Starting position: collapsed at the FAB centre
  static const Offset _closedPos = Offset(_fabCx, _fabCy);

  // Convert a centre-Offset to AnimatedPositioned.left
  static double _left(Offset c)   => c.dx - _miniSize / 2;
  // Convert a centre-Offset to AnimatedPositioned.bottom
  static double _bottom(Offset c) => _stackH - c.dy - _miniSize / 2;

  @override
  Widget build(BuildContext context) {
    // Distance from the bottom of the body area to the FAB bottom edge,
    // matching Flutter's standard centerFloat margin.
    final fabBottom =
        MediaQuery.of(context).padding.bottom + 16.0;

    // ── Voice active: show mic state widget centred at FAB position ──────────
    if (_voiceState != _VoiceInputState.idle) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            bottom: fabBottom,
            left: 0,
            right: 0,
            child: Center(child: _buildVoiceWidget()),
          ),
        ],
      );
    }

    // ── Normal state: backdrop + radial speed dial ───────────────────────────
    return Stack(
      fit: StackFit.expand,
      children: [
        // Backdrop — absorbs ALL pointer events when open (blocks scroll/swipe too)
        IgnorePointer(
          ignoring: !_open,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _open ? 1.0 : 0.0,
            child: GestureDetector(
              onTap: _closeDial,
              // opaque → swallows drags/scrolls as well
              behavior: HitTestBehavior.opaque,
              child: Container(
                color: Colors.black.withValues(alpha: 0.35),
              ),
            ),
          ),
        ),

        // Speed dial (positioned at the same spot as standard centerFloat FAB)
        Positioned(
          bottom: fabBottom,
          left: 0,
          right: 0,
          child: Center(
            child: SizedBox(
              width: _stackW,
              height: _stackH,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Mini radial buttons (behind the FAB)
                  _radialButton(
                    context,
                    icon: Icons.mic_outlined,
                    target: _micTarget,
                    onTap: _startVoice,
                  ),
                  _radialButton(
                    context,
                    icon: Icons.edit_outlined,
                    target: _pencilTarget,
                    onTap: () {
                      _closeDial();
                      context.push(AppRoutes.addTransaction);
                    },
                  ),
                  _radialButton(
                    context,
                    icon: Icons.camera_alt_outlined,
                    target: _cameraTarget,
                    onTap: _startCamera,
                  ),
                  // Main FAB (always on top)
                  Positioned(
                    left: (_stackW - _fabSize) / 2,
                    bottom: 0,
                    child: NeoFab(
                      icon: _open ? Icons.close : Icons.add,
                      onTap: _toggle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Builds one mini button that animates radially from the FAB centre.
  Widget _radialButton(
    BuildContext context, {
    required IconData icon,
    required Offset target,
    required VoidCallback onTap,
  }) {
    final centre = _open ? target : _closedPos;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      left:   _left(centre),
      bottom: _bottom(centre),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _open ? 1.0 : 0.0,
        child: IgnorePointer(
          ignoring: !_open,
          child: _MiniDialButton(icon: icon, onTap: onTap),
        ),
      ),
    );
  }

  Widget _buildVoiceWidget() {
    if (_voiceState == _VoiceInputState.processing ||
        _voiceState == _VoiceInputState.cameraProcessing) {
      return Container(
        width: _fabSize,
        height: _fabSize,
        decoration: const BoxDecoration(
          color: AppColors.dustyTeal,
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white,
            ),
          ),
        ),
      );
    }
    // Listening → red stop button
    return GestureDetector(
      onTap: () async {
        await _speech.stop();
        if (mounted) setState(() => _voiceState = _VoiceInputState.idle);
      },
      child: Container(
        width: _fabSize,
        height: _fabSize,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.stop_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

// ── Mini radial button ────────────────────────────────────────────────────────

class _MiniDialButton extends StatelessWidget {
  const _MiniDialButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.dustyTeal,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.dustyTeal.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
