import 'dart:io';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/core/config/app_config.dart';
import 'package:expense_manager/core/network/connectivity_service.dart';
import 'package:expense_manager/core/utils/app_logger.dart';

/// Banner de publicidad fijo en la parte inferior de la pantalla.
/// Se oculta automáticamente para usuarios PRO.
/// Cuando no hay conexión muestra un banner propio de promoción PRO.
class AdBannerFooter extends ConsumerStatefulWidget {
  const AdBannerFooter({super.key});

  @override
  ConsumerState<AdBannerFooter> createState() => _AdBannerFooterState();
}

class _AdBannerFooterState extends ConsumerState<AdBannerFooter> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  static String get _adUnitId => Platform.isAndroid
      ? AppConfig.admobAndroidBannerUnitId
      : AppConfig.admobIosBannerUnitId;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    final banner = BannerAd(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          AppLogger.log('[AdMob] Banner failed to load: $error');
          ad.dispose();
        },
      ),
    );
    _bannerAd = banner;
    banner.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(isProProvider)) return const SizedBox.shrink();

    final isOnline = ref.watch(isOnlineProvider);

    // Retry loading the AdMob banner when connectivity is restored.
    ref.listen(isOnlineProvider, (previous, next) {
      if (next && !_isLoaded && _bannerAd == null) {
        _loadAd();
      }
    });

    if (_isLoaded && _bannerAd != null) {
      return SafeArea(
        top: false,
        child: SizedBox(
          width: _bannerAd!.size.width.toDouble(),
          height: _bannerAd!.size.height.toDouble(),
          child: AdWidget(ad: _bannerAd!),
        ),
      );
    }

    // AdMob requires internet — show a house ad when offline.
    if (!isOnline) {
      return const _HouseAdBanner();
    }

    return const SizedBox.shrink();
  }
}

class _HouseAdBanner extends StatelessWidget {
  const _HouseAdBanner();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        height: 50,
        color: colorScheme.primaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIcons.crown(),
                size: 18, color: colorScheme.onPrimaryContainer),
            const SizedBox(width: 8),
            Text(
              '¡Pásate a PRO y elimina los anuncios!',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
