import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/extensions.dart';
import '../../core/widgets/neo_card.dart';
import '../../l10n/app_localizations.dart';
import 'subscription_provider.dart';
import 'subscription_repository.dart';
import 'subscription_state.dart';

class ProScreen extends ConsumerStatefulWidget {
  const ProScreen({super.key});

  @override
  ConsumerState<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends ConsumerState<ProScreen> {
  @override
  void initState() {
    super.initState();
    // Siempre consulta Supabase al abrir esta pantalla para reflejar
    // cambios recientes (suscripción manual, renovación, cancelación).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(subscriptionProvider.notifier).forceRefresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final subAsync = ref.watch(subscriptionProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.proPlanTitle),
      ),
      body: subAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.dustyTeal),
        ),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (sub) => _ProBody(sub: sub),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _ProBody extends ConsumerStatefulWidget {
  const _ProBody({required this.sub});
  final SubscriptionState sub;

  @override
  ConsumerState<_ProBody> createState() => _ProBodyState();
}

class _ProBodyState extends ConsumerState<_ProBody> {
  Package? _selectedPackage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = context.colors;
    final sub = widget.sub;
    final offeringsAsync = ref.watch(offeringsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          _ProHeader(isPro: sub.isPro, l10n: l10n),
          const Gap(28),

          // ── Active subscription card ─────────────────────────────────
          if (sub.isPro) ...[
            _ActiveProCard(
              expiresAt: sub.expiresAt!,
              source: sub.source,
              l10n: l10n,
            ),
            const Gap(24),
          ],

          // ── Benefits ─────────────────────────────────────────────────
          Text(
            l10n.proBenefitsTitle,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const Gap(14),
          _BenefitRow(
            icon: Icons.cloud_sync_outlined,
            iconColor: AppColors.dustyTeal,
            title: l10n.proCloudSync,
            subtitle: l10n.proCloudSyncSubtitle,
          ),
          _BenefitRow(
            icon: Icons.mic_outlined,
            iconColor: AppColors.dustyTeal,
            title: l10n.proVoiceImage,
            subtitle: l10n.proVoiceImageSubtitle,
          ),
          _BenefitRow(
            icon: Icons.smart_toy_outlined,
            iconColor: AppColors.warmAmber,
            title: l10n.proAIChat,
            subtitle: l10n.proAIChatSubtitle,
          ),
          _BenefitRow(
            icon: Icons.block_outlined,
            iconColor: AppColors.sageGreen,
            title: l10n.proNoBannerAds,
            subtitle: l10n.proNoBannerAdsSubtitle,
          ),
          const Gap(28),

          // ── Free trial card (only when eligible) ─────────────────────
          if (sub.canStartTrial) ...[
            _FreeTrialCard(sub: sub),
            const Gap(20),
          ],

          // ── Plan selector + purchase (only when not PRO) ─────────────
          if (!sub.isPro) ...[
            // ── Discount banner ───────────────────────────────────────
            if (sub.hasDiscount) ...[
              NeoCard(
                accentColor: AppColors.sageGreen,
                padding: const EdgeInsets.symmetric(
                    vertical: 12, horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.local_offer_outlined,
                        color: AppColors.sageGreen, size: 22),
                    const Gap(10),
                    Expanded(
                      child: Text(
                        l10n.proDiscountBanner(
                          sub.pendingDiscountPercentage!,
                          sub.discountBonusDays,
                        ),
                        style: const TextStyle(
                          fontFamily: 'Sora',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.sageGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(16),
            ],

            // ── Plan picker from store ────────────────────────────────
            offeringsAsync.when(
              loading: () => const _PlanPickerSkeleton(),
              error: (_, __) => _PlanPickerFallback(l10n: l10n),
              data: (offering) {
                if (offering == null) return _PlanPickerFallback(l10n: l10n);
                final packages = _sortedPackages(offering);
                if (packages.isEmpty) {
                  return _PlanPickerFallback(l10n: l10n);
                }
                // Pre-select the first package (annual if available, else monthly).
                final effective = _selectedPackage ?? packages.first;
                return _PlanPicker(
                  packages: packages,
                  selected: effective,
                  onChanged: (p) => setState(() => _selectedPackage = p),
                );
              },
            ),
            const Gap(20),

            // Error message
            if (sub.purchaseError != null) ...[
              Text(
                sub.purchaseError!,
                style: TextStyle(
                  fontFamily: 'Sora',
                  color: cs.error,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const Gap(12),
            ],

            // Subscribe button
            offeringsAsync.when(
              loading: () => NeoBrutalButton(
                label: l10n.proSubscribe,
                isLoading: true,
                onTap: null,
              ),
              error: (_, __) => NeoBrutalButton(
                label: l10n.proSubscribe,
                isLoading: sub.isLoading,
                onTap: null,
              ),
              data: (offering) {
                final packages = offering != null
                    ? _sortedPackages(offering)
                    : <Package>[];
                final effective = packages.isEmpty
                    ? null
                    : (_selectedPackage ?? packages.first);
                return NeoBrutalButton(
                  label: l10n.proSubscribe,
                  isLoading: sub.isLoading,
                  onTap: (sub.isLoading || effective == null)
                      ? null
                      : () => ref
                          .read(subscriptionProvider.notifier)
                          .purchase(effective),
                );
              },
            ),
            const Gap(12),

            // Restore purchases
            TextButton(
              onPressed: sub.isLoading
                  ? null
                  : () =>
                      ref.read(subscriptionProvider.notifier).restorePurchases(),
              child: Text(
                l10n.proRestorePurchases,
                style: const TextStyle(
                  fontFamily: 'Sora',
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ),

            // Promo code
            TextButton(
              onPressed: sub.isLoading
                  ? null
                  : () => showDialog<void>(
                        context: context,
                        builder: (_) => const _PromoCodeDialog(),
                      ),
              child: Text(
                l10n.promoCodeTitle,
                style: const TextStyle(
                  fontFamily: 'Sora',
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ),
          ],

          // ── Already PRO: refresh button ───────────────────────────────
          if (sub.isPro)
            OutlinedButton.icon(
              onPressed: () =>
                  ref.read(subscriptionProvider.notifier).forceRefresh(),
              icon: const Icon(Icons.refresh_outlined, size: 18),
              label: Text(l10n.proRefreshStatus),
            ),

          const Gap(24),

          // ── Legal disclaimer ──────────────────────────────────────────
          Text(
            l10n.proLegalDisclaimer,
            style: const TextStyle(
              fontFamily: 'Sora',
              fontSize: 11,
              color: AppColors.textSubtle,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Annual first (best value), then monthly, then the rest.
  List<Package> _sortedPackages(Offering offering) {
    final all = offering.availablePackages;
    final annual = all.where((p) => p.packageType == PackageType.annual).toList();
    final monthly = all.where((p) => p.packageType == PackageType.monthly).toList();
    final rest = all
        .where((p) =>
            p.packageType != PackageType.annual &&
            p.packageType != PackageType.monthly)
        .toList();
    return [...annual, ...monthly, ...rest];
  }
}

// ── Plan picker ───────────────────────────────────────────────────────────────

class _PlanPicker extends StatelessWidget {
  const _PlanPicker({
    required this.packages,
    required this.selected,
    required this.onChanged,
  });

  final List<Package> packages;
  final Package selected;
  final ValueChanged<Package> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: packages.map((pkg) {
        final isSelected = pkg.identifier == selected.identifier;
        final isAnnual = pkg.packageType == PackageType.annual;
        final price = pkg.storeProduct.priceString;
        final savingsLabel = _annualSavings(packages, pkg);

        return GestureDetector(
          onTap: () => onChanged(pkg),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.dustyTeal.withValues(alpha: 0.08)
                  : Colors.transparent,
              border: Border.all(
                color: isSelected ? AppColors.dustyTeal : AppColors.textMuted.withValues(alpha: 0.3),
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: isSelected ? AppColors.dustyTeal : AppColors.textMuted,
                  size: 20,
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _periodLabel(context, pkg),
                            style: TextStyle(
                              fontFamily: 'Sora',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? AppColors.dustyTeal
                                  : null,
                            ),
                          ),
                          if (isAnnual && savingsLabel != null) ...[
                            const Gap(8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.sageGreen,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                savingsLabel,
                                style: const TextStyle(
                                  fontFamily: 'Sora',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        _perMonthLabel(context, pkg),
                        style: const TextStyle(
                          fontFamily: 'Sora',
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  price,
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? AppColors.dustyTeal : null,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _periodLabel(BuildContext context, Package pkg) {
    final l10n = AppLocalizations.of(context);
    return switch (pkg.packageType) {
      PackageType.annual => l10n.planAnnual,
      PackageType.monthly => l10n.planMonthly,
      PackageType.weekly => l10n.planWeekly,
      _ => pkg.storeProduct.title,
    };
  }

  String _perMonthLabel(BuildContext context, Package pkg) {
    final l10n = AppLocalizations.of(context);
    if (pkg.packageType == PackageType.annual) {
      final perMonth = pkg.storeProduct.price / 12;
      final symbol = _currencySymbol(pkg.storeProduct.currencyCode);
      return l10n.planPerMonth('$symbol${perMonth.toStringAsFixed(2)}');
    }
    return l10n.proPriceSubtitle;
  }

  String _currencySymbol(String code) => switch (code.toUpperCase()) {
        'EUR' => '€',
        'USD' => '\$',
        'GBP' => '£',
        _ => '$code ',
      };

  /// Returns a "Save X%" label when the annual plan is cheaper per month
  /// than the monthly plan.
  String? _annualSavings(List<Package> all, Package annualPkg) {
    final monthly = all.firstWhere(
      (p) => p.packageType == PackageType.monthly,
      orElse: () => annualPkg,
    );
    if (monthly.identifier == annualPkg.identifier) return null;
    final monthlyPrice = monthly.storeProduct.price;
    if (monthlyPrice <= 0) return null;
    final annualPerMonth = annualPkg.storeProduct.price / 12;
    final savings = ((1 - annualPerMonth / monthlyPrice) * 100).round();
    if (savings <= 0) return null;
    return '-$savings%';
  }
}

class _PlanPickerFallback extends StatelessWidget {
  const _PlanPickerFallback({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return NeoCard(
      accentColor: AppColors.warmAmber,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            l10n.proPrice,
            style: context.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.dustyTeal,
            ),
          ),
          const Gap(4),
          Text(
            l10n.proPriceSubtitle,
            style: const TextStyle(
              fontFamily: 'Sora',
              fontSize: 13,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanPickerSkeleton extends StatelessWidget {
  const _PlanPickerSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(2, (i) {
        return Container(
          height: 62,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppColors.textMuted.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
        );
      }),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _ProHeader extends StatelessWidget {
  const _ProHeader({required this.isPro, required this.l10n});
  final bool isPro;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            color: AppColors.warmAmberLight,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.star_rounded,
            size: 44,
            color: AppColors.warmAmber,
          ),
        ),
        const Gap(16),
        Text(
          isPro ? l10n.proHeaderActiveTitle : l10n.proHeaderInactiveTitle,
          style: context.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const Gap(6),
        Text(
          isPro
              ? l10n.proHeaderActiveSubtitle
              : l10n.proHeaderInactiveSubtitle,
          style: TextStyle(
            fontFamily: 'Sora',
            fontSize: 14,
            color: context.colors.onSurface.withValues(alpha: 0.55),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Active card ───────────────────────────────────────────────────────────────

class _ActiveProCard extends StatelessWidget {
  const _ActiveProCard({
    required this.expiresAt,
    required this.l10n,
    this.source,
  });
  final DateTime expiresAt;
  final String? source;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final remaining = expiresAt.difference(DateTime.now()).inDays;
    final sourceLabel = switch (source) {
      'play_store' => l10n.proSourceGooglePlay,
      'app_store' => l10n.proSourceAppStore,
      'promo_code' => l10n.proSourcePromoCode,
      'free_trial' => l10n.proSourceFreeTrial,
      _ => '',
    };

    return NeoCard(
      accentColor: AppColors.sageGreen,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Row(
        children: [
          const Icon(
            Icons.verified_rounded,
            color: AppColors.sageGreen,
            size: 28,
          ),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.proActiveCardTitle,
                  style: const TextStyle(
                    fontFamily: 'Sora',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.sageGreen,
                  ),
                ),
                const Gap(2),
                Text(
                  l10n.proActiveCardExpiry(remaining, sourceLabel),
                  style: const TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Benefit row ───────────────────────────────────────────────────────────────

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.check_circle_outline,
            color: AppColors.sageGreen,
            size: 18,
          ),
        ],
      ),
    );
  }
}

// ── Free trial card ──────────────────────────────────────────────────────────

class _FreeTrialCard extends ConsumerWidget {
  const _FreeTrialCard({required this.sub});
  final SubscriptionState sub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return NeoCard(
      accentColor: AppColors.dustyTeal,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(
            Icons.rocket_launch_outlined,
            color: AppColors.dustyTeal,
            size: 32,
          ),
          const Gap(12),
          Text(
            l10n.proFreeTrialButton,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.dustyTeal,
            ),
          ),
          const Gap(4),
          Text(
            l10n.proFreeTrialSubtitle,
            style: const TextStyle(
              fontFamily: 'Sora',
              fontSize: 13,
              color: AppColors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
          const Gap(16),
          NeoBrutalButton(
            label: l10n.proFreeTrialButton,
            isLoading: sub.isLoading,
            onTap: sub.isLoading
                ? null
                : () async {
                    await ref
                        .read(subscriptionProvider.notifier)
                        .startFreeTrial();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.proFreeTrialActivated),
                          backgroundColor: AppColors.sageGreen,
                        ),
                      );
                    }
                  },
          ),
        ],
      ),
    );
  }
}

// ── Promo code dialog ─────────────────────────────────────────────────────────

class _PromoCodeDialog extends ConsumerStatefulWidget {
  const _PromoCodeDialog();

  @override
  ConsumerState<_PromoCodeDialog> createState() => _PromoCodeDialogState();
}

class _PromoCodeDialogState extends ConsumerState<_PromoCodeDialog> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final code = _controller.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(subscriptionProvider.notifier)
          .redeemPromoCode(code);
      if (mounted) Navigator.of(context).pop();
    } on PromoCodeException catch (e) {
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = AppLocalizations.of(context).proPromoUnexpectedError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(
        l10n.promoCodeTitle,
        style: const TextStyle(fontFamily: 'Sora', fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: l10n.promoCodeHint,
              hintStyle: const TextStyle(fontFamily: 'Sora'),
            ),
            onSubmitted: (_) => _apply(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(
                fontFamily: 'Sora',
                fontSize: 12,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: Text(
            l10n.cancel,
            style: const TextStyle(fontFamily: 'Sora', color: AppColors.textMuted),
          ),
        ),
        TextButton(
          onPressed: _loading ? null : _apply,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.dustyTeal,
                  ),
                )
              : Text(
                  l10n.apply,
                  style: const TextStyle(
                    fontFamily: 'Sora',
                    fontWeight: FontWeight.w700,
                    color: AppColors.dustyTeal,
                  ),
                ),
        ),
      ],
    );
  }
}
