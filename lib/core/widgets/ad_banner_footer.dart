import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../features/subscription/subscription_provider.dart';
import '../config/app_config.dart';

/// Banner de publicidad fijo en la parte inferior de la pantalla.
/// Se oculta automáticamente para usuarios PRO.
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
          debugPrint('[AdMob] Banner failed to load: $error');
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
    if (!_isLoaded || _bannerAd == null) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}
