import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:expense_manager/core/utils/extensions.dart';
import 'package:expense_manager/l10n/app_localizations.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/features/subscription/subscription_repository.dart';

/// Diálogo único de canje de código promocional (drawer y pantalla PRO).
///
/// Sigue el patrón de diálogos de la app: TextButton para cancelar,
/// FilledButton para la acción primaria, y snackbar flotante de éxito
/// (los estilos de texto vienen del theme — GeneralSans global).
class PromoCodeDialog extends ConsumerStatefulWidget {
  const PromoCodeDialog({super.key});

  @override
  ConsumerState<PromoCodeDialog> createState() => _PromoCodeDialogState();
}

class _PromoCodeDialogState extends ConsumerState<PromoCodeDialog> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _applyCode() async {
    final code = _controller.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(subscriptionProvider.notifier).redeemPromoCode(code);
      if (!mounted) return;
      Navigator.of(context).pop();
      context.showSnackbar(AppLocalizations.of(context).proPromoSuccess);
    } on PromoCooldownException catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() {
          _error = l10n.errorPromoTooManyAttempts(e.remainingSeconds);
          _loading = false;
        });
      }
    } on PromoCodeException catch (e) {
      // Server-driven message (invalid/expired code) — surfaced as-is.
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() {
          _error = l10n.proPromoUnexpectedError;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.promoCodeTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 20,
            textCapitalization: TextCapitalization.characters,
            enabled: !_loading,
            decoration: InputDecoration(
              hintText: l10n.promoCodeHint,
              prefixIcon: Icon(PhosphorIcons.tag()),
            ),
            onSubmitted: (_) => _applyCode(),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _loading ? null : _applyCode,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(l10n.apply),
        ),
      ],
    );
  }
}
