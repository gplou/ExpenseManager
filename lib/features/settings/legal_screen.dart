import 'package:flutter/material.dart';

import 'package:expense_manager/core/theme/app_spacing.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingLg,
        child: SelectableText(
          content,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
