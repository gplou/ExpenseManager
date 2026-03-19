import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/extensions.dart';
import '../../core/widgets/neo_card.dart';
import '../../l10n/app_localizations.dart';
import 'subscription_provider.dart';
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

class _ProBody extends ConsumerWidget {
  const _ProBody({required this.sub});
  final SubscriptionState sub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cs = context.colors;

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
            icon: Icons.block_outlined,
            iconColor: AppColors.sageGreen,
            title: l10n.proNoBannerAds,
            subtitle: l10n.proNoBannerAdsSubtitle,
          ),
          _BenefitRow(
            icon: Icons.mic_outlined,
            iconColor: AppColors.dustyTeal,
            title: l10n.proVoiceAI,
            subtitle: l10n.proVoiceAISubtitle,
          ),
          _BenefitRow(
            icon: Icons.auto_awesome_outlined,
            iconColor: AppColors.warmAmber,
            title: l10n.proFutureFeatures,
            subtitle: l10n.proFutureFeaturesSubtitle,
          ),
          const Gap(28),

          // ── Free trial card (only when eligible) ─────────────────────
          if (sub.canStartTrial) ...[
            _FreeTrialCard(sub: sub),
            const Gap(20),
          ],

          // ── Price card (only when not PRO) ───────────────────────────
          if (!sub.isPro) ...[
            // ── Discount banner (when a discount promo code has been redeemed)
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

            NeoCard(
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
            NeoBrutalButton(
              label: l10n.proSubscribe,
              isLoading: sub.isLoading,
              onTap: sub.isLoading
                  ? null
                  : () =>
                      ref.read(subscriptionProvider.notifier).purchase(),
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
            boxShadow: AppColors.shadowAmber,
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
      'google_play' => l10n.proSourceGooglePlay,
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
