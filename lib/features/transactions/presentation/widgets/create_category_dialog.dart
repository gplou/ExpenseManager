import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/utils/extensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/transaction_categories.dart';
import '../../domain/transaction_model.dart';
import '../providers/custom_categories_provider.dart';

const _pickableIcons = [
  Icons.sports_soccer_outlined,
  Icons.fitness_center_outlined,
  Icons.directions_bike_outlined,
  Icons.flight_outlined,
  Icons.hotel_outlined,
  Icons.local_cafe_outlined,
  Icons.local_bar_outlined,
  Icons.movie_outlined,
  Icons.music_note_outlined,
  Icons.book_outlined,
  Icons.local_pharmacy_outlined,
  Icons.spa_outlined,
  Icons.pets_outlined,
  Icons.child_care_outlined,
  Icons.shopping_cart_outlined,
  Icons.local_gas_station_outlined,
  Icons.directions_bus_outlined,
  Icons.handyman_outlined,
  Icons.park_outlined,
  Icons.beach_access_outlined,
  Icons.savings_outlined,
  Icons.card_membership_outlined,
  Icons.volunteer_activism_outlined,
  Icons.subscriptions_outlined,
];

class CreateCategoryDialog extends ConsumerStatefulWidget {
  const CreateCategoryDialog({super.key, required this.type});

  final TransactionType type;

  @override
  ConsumerState<CreateCategoryDialog> createState() =>
      _CreateCategoryDialogState();
}

class _CreateCategoryDialogState extends ConsumerState<CreateCategoryDialog> {
  final _nameController = TextEditingController();
  IconData? _selectedIcon;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _selectedIcon == null) return;

    await ref.read(customCategoriesProvider.notifier).add(
          widget.type,
          TransactionCategory(name: name, icon: _selectedIcon!),
        );
    if (mounted) Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canSave =
        _nameController.text.trim().isNotEmpty && _selectedIcon != null;

    return AlertDialog(
      title: Text(l10n.newCategory),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.categoryName),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _save(),
            ),
            const Gap(16),
            Text(l10n.chooseIcon, style: context.textTheme.labelMedium),
            const Gap(8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _pickableIcons.map((icon) {
                final isSelected = _selectedIcon == icon;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = icon),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? context.colors.primaryContainer
                          : context.colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                      border: isSelected
                          ? Border.all(color: context.colors.primary, width: 2)
                          : null,
                    ),
                    child: Icon(
                      icon,
                      size: 22,
                      color: isSelected
                          ? context.colors.primary
                          : context.colors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: canSave ? _save : null,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
