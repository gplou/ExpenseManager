import 'package:flutter/material.dart';

import 'package:expense_manager/core/theme/app_colors.dart';

/// Small amber "PRO" chip shown next to locked features in the drawer.
class ProBadge extends StatelessWidget {
  const ProBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.warmAmber,
        borderRadius: BorderRadius.circular(100),
      ),
      child: const Text(
        'PRO',
        style: TextStyle(
          fontFamily: 'GeneralSans',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
