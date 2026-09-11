import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:expense_manager/core/theme/app_colors.dart';
import 'package:expense_manager/core/utils/extensions.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

class ExportButton extends StatelessWidget {
  const ExportButton(
      {super.key, required this.onTap, required this.exporting, required this.label});
  final VoidCallback? onTap;
  final bool exporting;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(top: BorderSide(color: context.appColors.divider, width: 1)),
        ),
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: exporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.paper,
                  ),
                )
              : Icon(PhosphorIcons.downloadSimple(), size: 18),
          label: Text(label),
        ),
      ),
    );
  }
}

// ── Delete selected button ────────────────────────────────────────────────────

class DeleteSelectedButton extends StatelessWidget {
  const DeleteSelectedButton({super.key, required this.count, required this.onTap});
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(top: BorderSide(color: context.appColors.divider, width: 1)),
        ),
        child: ElevatedButton.icon(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.negative,
            foregroundColor: AppColors.paper,
            disabledBackgroundColor:
                AppColors.negative.withValues(alpha: 0.4),
            disabledForegroundColor: AppColors.paper,
          ),
          icon: Icon(PhosphorIcons.trash(), size: 18),
          label: Text('${l10n.delete} ($count)'),
        ),
      ),
    );
  }
}
