import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:expense_manager/core/services/analytics_service.dart';
import 'package:expense_manager/core/widgets/ad_banner_footer.dart';
import 'package:expense_manager/core/widgets/app_bottom_nav.dart';
import 'package:expense_manager/features/dashboard/widgets/app_drawer.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';

/// Contenedor de las cuatro pestañas: barra inferior, banner y drawer.
///
/// Las pantallas de pestaña no saben que viven aquí — no deben llamar a
/// `StatefulNavigationShell.of`. Eso es lo que permite seguir montándolas
/// sueltas en los widget tests sin router.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Nombre de pantalla por índice de rama, para analítica.
  ///
  /// `AnalyticsRouteObserver` solo reacciona a push/replace, y cambiar de
  /// pestaña con `IndexedStack` no es ninguna de las dos: sin esto, las
  /// pantallas de las pestañas dejarían de aparecer en PostHog.
  static const _screenNames = ['dashboard', 'transactions', 'budgets', 'charts'];

  void _onSelect(int index) {
    // Volver a tocar la pestaña activa la devuelve a su raíz, que es lo que
    // espera todo el mundo de una barra inferior.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
    AnalyticsService.screen(_screenNames[index]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPro = ref.watch(isProProvider);

    return Scaffold(
      drawer: const AppDrawer(),
      body: navigationShell,
      // Banner encima de la barra, ambos dentro del slot de
      // `bottomNavigationBar`: así el Scaffold descuenta su alto del body y
      // las pantallas no tienen que reservar hueco a mano.
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isPro) const AdBannerFooter(),
          AppBottomNav(
            currentIndex: navigationShell.currentIndex,
            onSelect: _onSelect,
          ),
        ],
      ),
    );
  }
}
