import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/utils/extensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/transaction_categories.dart';
import '../../domain/transaction_model.dart';
import '../providers/custom_categories_provider.dart';


class CreateCategoryDialog extends ConsumerStatefulWidget {
  const CreateCategoryDialog({super.key, required this.type});

  final TransactionType type;

  @override
  ConsumerState<CreateCategoryDialog> createState() =>
      _CreateCategoryDialogState();
}

class _CreateCategoryDialogState extends ConsumerState<CreateCategoryDialog> {
  final _nameController = TextEditingController();
  final _emojiController = TextEditingController();
  String? _selectedEmoji;

  @override
  void dispose() {
    _nameController.dispose();
    _emojiController.dispose();
    super.dispose();
  }

  void _onEmojiChanged(String value) {
    // Extract only the first grapheme cluster (emoji)
    final characters = value.characters;
    if (characters.isEmpty) {
      setState(() {
        _selectedEmoji = null;
        _emojiController.clear();
      });
      return;
    }
    final firstEmoji = characters.first;
    setState(() => _selectedEmoji = firstEmoji);
    // Keep only the first emoji in the field
    if (characters.length > 1) {
      _emojiController.text = firstEmoji;
      _emojiController.selection = TextSelection.fromPosition(
        TextPosition(offset: firstEmoji.length),
      );
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _selectedEmoji == null) return;

    final codePoint = _selectedEmoji!.runes.first;
    await ref.read(customCategoriesProvider.notifier).add(
          widget.type,
          TransactionCategory(name: name, icon: IconData(codePoint)),
        );
    if (mounted) Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canSave =
        _nameController.text.trim().isNotEmpty && _selectedEmoji != null;

    return AlertDialog(
      title: Text(l10n.newCategory),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Emoji field
              SizedBox(
                width: 56,
                child: TextField(
                  controller: _emojiController,
                  onChanged: _onEmojiChanged,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 28),
                  decoration: InputDecoration(
                    hintText: '😀',
                    hintStyle: TextStyle(
                      fontSize: 28,
                      color: context.colors.onSurface.withValues(alpha: 0.3),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const Gap(12),
              // Name field
              Expanded(
                child: TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.sentences,
                  autofocus: true,
                  maxLength: 15,
                  decoration: InputDecoration(labelText: l10n.categoryName),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _save(),
                ),
              ),
            ],
          ),
        ],
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
