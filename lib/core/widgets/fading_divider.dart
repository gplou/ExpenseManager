import 'package:flutter/material.dart';

import 'package:expense_manager/core/utils/extensions.dart';

/// Hairline horizontal que se desvanece a transparente en ambos extremos, en
/// vez de cortar en seco contra el borde del contenedor.
///
/// [fadeLength] es la distancia en px sobre la que ocurre el desvanecido a
/// cada lado (48 por defecto, por spec). Se recorta a la mitad del ancho
/// disponible para no solaparse en contenedores muy estrechos.
class FadingDivider extends StatelessWidget {
  const FadingDivider({super.key, this.color, this.fadeLength = 48});

  final Color? color;
  final double fadeLength;

  @override
  Widget build(BuildContext context) {
    final lineColor = color ?? context.appColors.divider;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final stop = width > 0 ? (fadeLength / width).clamp(0.0, 0.5) : 0.0;
        return Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                lineColor.withValues(alpha: 0),
                lineColor,
                lineColor,
                lineColor.withValues(alpha: 0),
              ],
              stops: [0.0, stop, 1.0 - stop, 1.0],
            ),
          ),
        );
      },
    );
  }
}
