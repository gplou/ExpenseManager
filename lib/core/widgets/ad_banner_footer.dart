import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../utils/extensions.dart';
import '../../features/subscription/subscription_provider.dart';

/// Banner de publicidad fijo en la parte inferior de la pantalla.
/// Se oculta automáticamente para usuarios PRO.
class AdBannerFooter extends ConsumerWidget {
  const AdBannerFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(isProProvider)) return const SizedBox.shrink();

    final cs = context.colors;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      width: double.infinity,
      height: 56 + bottomPadding,
      decoration: BoxDecoration(
        color: cs.surface,
        border: const Border(
          top: BorderSide(color: AppColors.borderLight, width: 1),
        ),
        boxShadow: AppColors.softShadowSm,
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
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
      ),
    );
  }
}
