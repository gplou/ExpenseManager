import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/subcategories_repository.dart';
import '../../domain/transaction_model.dart';

class CreateSubcategoryDialog extends ConsumerStatefulWidget {
  const CreateSubcategoryDialog({
    super.key,
    required this.category,
    required this.type,
  });

  final String category;
  final TransactionType type;

  @override
  ConsumerState<CreateSubcategoryDialog> createState() =>
      _CreateSubcategoryDialogState();
}

class _CreateSubcategoryDialogState
    extends ConsumerState<CreateSubcategoryDialog> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    await ref
        .read(subcategoriesRepositoryProvider)
        .add(widget.category, widget.type, name);
    if (mounted) Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canSave = _nameController.text.trim().isNotEmpty;

    return AlertDialog(
      title: Text(l10n.newSubcategory),
      content: TextField(
        controller: _nameController,
        textCapitalization: TextCapitalization.sentences,
        autofocus: true,
        decoration: InputDecoration(labelText: l10n.subcategoryName),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _save(),
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
