import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Banner de publicidad fijo en la parte inferior de la pantalla.
/// Se oculta automáticamente para usuarios PRO.
/// TODO: Replace with real AdMob banner.
class AdBannerFooter extends ConsumerWidget {
  const AdBannerFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SizedBox.shrink();
  }
}
