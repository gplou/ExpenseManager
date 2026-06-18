import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:expense_manager/core/theme/app_colors.dart';
import 'package:expense_manager/core/utils/extensions.dart';
import 'package:expense_manager/core/widgets/neo_card.dart';
import 'package:expense_manager/l10n/app_localizations.dart';
import 'subscription_provider.dart';
import 'subscription_state.dart';
import 'widgets/plan_picker.dart';
import 'widgets/pro_cards.dart';
import 'widgets/promo_code_dialog.dart';
import 'widgets/subscription_error_l10n.dart';

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
          ProHeader(isPro: sub.isPro, l10n: l10n),
          const Gap(28),

          // ── Active subscription card ─────────────────────────────────
          if (sub.isPro) ...[
            ActiveProCard(
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
          BenefitRow(
            icon: Icons.cloud_sync_outlined,
            iconColor: AppColors.dustyTeal,
            title: l10n.proCloudSync,
            subtitle: l10n.proCloudSyncSubtitle,
          ),
          BenefitRow(
            icon: Icons.mic_outlined,
            iconColor: AppColors.dustyTeal,
            title: l10n.proVoiceImage,
            subtitle: l10n.proVoiceImageSubtitle,
          ),
          BenefitRow(
            icon: Icons.smart_toy_outlined,
            iconColor: AppColors.warmAmber,
            title: l10n.proAIChat,
            subtitle: l10n.proAIChatSubtitle,
          ),
          BenefitRow(
            icon: Icons.block_outlined,
            iconColor: AppColors.sageGreen,
            title: l10n.proNoBannerAds,
            subtitle: l10n.proNoBannerAdsSubtitle,
          ),
          const Gap(28),

          // ── Free trial card (only when eligible) ─────────────────────
          if (sub.canStartTrial) ...[
            FreeTrialCard(sub: sub),
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
                          fontFamily: 'GeneralSans',
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
              loading: () => const PlanPickerSkeleton(),
              error: (_, __) => PlanPickerFallback(l10n: l10n),
              data: (offering) {
                if (offering == null) return PlanPickerFallback(l10n: l10n);
                final packages = _sortedPackages(offering);
                if (packages.isEmpty) {
                  return PlanPickerFallback(l10n: l10n);
                }
                // Pre-select the first package (annual if available, else monthly).
                final effective = _selectedPackage ?? packages.first;
                return PlanPicker(
                  packages: packages,
                  selected: effective,
                  onChanged: (p) => setState(() => _selectedPackage = p),
                );
              },
            ),
            const Gap(20),

            // Error message
            if (sub.errorCode != null) ...[
              Text(
                subscriptionErrorMessage(l10n, sub.errorCode!),
                style: TextStyle(
                  fontFamily: 'GeneralSans',
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
                  fontFamily: 'GeneralSans',
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
                        builder: (_) => const PromoCodeDialog(),
                      ),
              child: Text(
                l10n.promoCodeTitle,
                style: const TextStyle(
                  fontFamily: 'GeneralSans',
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
              fontFamily: 'GeneralSans',
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
