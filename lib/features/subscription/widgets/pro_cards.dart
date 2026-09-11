import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import 'package:expense_manager/core/theme/app_colors.dart';
import 'package:expense_manager/core/utils/extensions.dart';
import 'package:expense_manager/core/widgets/neo_card.dart';
import 'package:expense_manager/l10n/app_localizations.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/features/subscription/subscription_state.dart';

class ProHeader extends StatelessWidget {
  const ProHeader({super.key, required this.isPro, required this.l10n});
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
          child: Icon(
            PhosphorIcons.star(),
            size: 44,
            color: AppColors.warmAmber,
          ),
        ),
        const Gap(16),
        Text(
          isPro ? l10n.proHeaderActiveTitle : l10n.proHeaderInactiveTitle,
          style: context.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const Gap(6),
        Text(
          isPro
              ? l10n.proHeaderActiveSubtitle
              : l10n.proHeaderInactiveSubtitle,
          style: TextStyle(
            fontFamily: 'Inter',
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

class ActiveProCard extends StatelessWidget {
  const ActiveProCard({super.key, 
    required this.expiresAt,
    required this.l10n,
    this.source,
  });
  final DateTime expiresAt;
  final String? source;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final remaining = expiresAt.difference(clock.now()).inDays;
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
          Icon(
            PhosphorIcons.sealCheck(),
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
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.sageGreen,
                  ),
                ),
                const Gap(2),
                Text(
                  l10n.proActiveCardExpiry(remaining, sourceLabel),
                  style: const TextStyle(
                    fontFamily: 'Inter',
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

class BenefitRow extends StatelessWidget {
  const BenefitRow({super.key, 
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
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            PhosphorIcons.checkCircle(),
            color: AppColors.sageGreen,
            size: 18,
          ),
        ],
      ),
    );
  }
}

// ── Free trial card ──────────────────────────────────────────────────────────

class FreeTrialCard extends ConsumerWidget {
  const FreeTrialCard({super.key, required this.sub});
  final SubscriptionState sub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return NeoCard(
      accentColor: AppColors.dustyTeal,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(
            PhosphorIcons.rocketLaunch(),
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
              fontFamily: 'Inter',
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
