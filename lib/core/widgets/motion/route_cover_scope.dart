import 'package:flutter/widgets.dart';

/// Publica hacia abajo si la ruta que contiene este scope está tapada por
/// otra (una hoja modal, un diálogo, una pantalla encima).
///
/// Hace falta porque las pestañas viven en navegadores anidados: la hoja de
/// "nueva transacción" se abre en el navegador raíz, así que para el dashboard
/// su propia ruta (la de la rama) sigue siendo la actual aunque esté tapado.
/// `AppShell` vive en la ruta del navegador raíz y monta este scope, así que
/// sí se entera.
///
/// Los widgets del kit lo consultan con [isCovered] para no gastar sus
/// animaciones de "esto acaba de cambiar" debajo de la hoja: esperan a que se
/// destape y entonces animan, que es cuando el usuario puede verlo.
class RouteCoverScope extends StatelessWidget {
  const RouteCoverScope({super.key, required this.child});

  final Widget child;

  /// true si alguna ruta por encima de [context] lo está tapando: la propia
  /// (diálogos/hojas en el mismo navegador) o la del [RouteCoverScope] más
  /// cercano (hojas abiertas en un navegador ancestro). Registra dependencia:
  /// el widget se reconstruye cuando cambia.
  static bool isCovered(BuildContext context) {
    final scoped = context
            .dependOnInheritedWidgetOfExactType<_RouteCoverStatus>()
            ?.covered ??
        false;
    return scoped || !(ModalRoute.isCurrentOf(context) ?? true);
  }

  @override
  Widget build(BuildContext context) {
    return _RouteCoverStatus(
      covered: !(ModalRoute.isCurrentOf(context) ?? true),
      child: child,
    );
  }
}

class _RouteCoverStatus extends InheritedWidget {
  const _RouteCoverStatus({required this.covered, required super.child});

  final bool covered;

  @override
  bool updateShouldNotify(_RouteCoverStatus oldWidget) =>
      covered != oldWidget.covered;
}
