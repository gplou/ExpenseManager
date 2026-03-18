import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/router.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/extensions.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../subscription/subscription_provider.dart';
import '../../subscription/subscription_repository.dart';
import '../../subscription/widgets/pro_badge.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(currentUserProvider);
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            _DrawerHeader(user: user),
            const Divider(height: 1),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // ── Ajustes de usuario ────────────────────────────────────
                  _SectionLabel(l10n.userSettings),
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(l10n.username),
                    subtitle: Text(
                      user?.name?.isNotEmpty == true
                          ? user!.name!
                          : l10n.noName,
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => _showEditNameSheet(context, ref, user?.name),
                  ),
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: Text(l10n.changePassword),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () =>
                        _confirmChangePassword(context, ref, user?.email),
                  ),
                  const Gap(8),

                  // ── Ajustes de la app ──────────────────────────────────────
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: Text(l10n.appSettings),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push(AppRoutes.appSettings);
                    },
                  ),
                  // ── Plan PRO ──────────────────────────────────────────
                  Consumer(
                    builder: (context, ref, _) {
                      final isPro = ref.watch(isProProvider);
                      final sub = ref.watch(subscriptionProvider).valueOrNull;
                      return ListTile(
                        leading: Icon(
                          Icons.star_rounded,
                          color: isPro
                              ? AppColors.warmAmber
                              : AppColors.textMuted,
                        ),
                        title: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                l10n.proPlanTitle,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (!isPro) const ProBadge(),
                          ],
                        ),
                        subtitle: Text(
                          isPro && sub?.expiresAt != null
                              ? l10n.proActiveStatus(
                                  sub!.expiresAt!
                                      .difference(DateTime.now())
                                      .inDays,
                                )
                              : l10n.proDrawerSubtitle,
                        ),
                        trailing:
                            const Icon(Icons.chevron_right, size: 18),
                        onTap: () {
                          Navigator.of(context).pop();
                          context.push(AppRoutes.pro);
                        },
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.local_offer_outlined),
                    title: Text(AppLocalizations.of(context).promoCodeTitle),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => _showPromoCodeDialog(context),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // ── Logout ────────────────────────────────────────────────────
            ListTile(
              leading: Icon(
                Icons.logout_outlined,
                color: context.colors.error,
              ),
              title: Text(
                l10n.logout,
                style: TextStyle(color: context.colors.error),
              ),
              onTap: () {
                Navigator.of(context).pop();
                ref.read(authNotifierProvider.notifier).signOut();
              },
            ),
            const Gap(8),
          ],
        ),
      ),
    );
  }

  void _showPromoCodeDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => const _PromoCodeDialog(),
    );
  }

  Future<void> _confirmChangePassword(
    BuildContext context,
    WidgetRef ref,
    String? email,
  ) async {
    if (email == null) return;
    final l10n = AppLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.changePassword),
        content: Text(l10n.changePasswordContent(email)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.send),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(supabaseClientProvider).auth.resetPasswordForEmail(email);
      if (!context.mounted) return;
      Navigator.of(context).pop();
      context.showSnackbar(l10n.checkEmailPassword);
    } catch (_) {
      if (!context.mounted) return;
      context.showSnackbar(l10n.errorSendingEmail, isError: true);
    }
  }

  void _showEditNameSheet(
    BuildContext context,
    WidgetRef ref,
    String? currentName,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
        ),
        child: _EditNameSheet(
          currentName: currentName,
          onSaved: () {
            Navigator.of(sheetCtx).pop();
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}

// ── Drawer header ─────────────────────────────────────────────────────────────

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.user});
  final dynamic user;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = (user?.name as String?)?.trim();
    final email = user?.email as String?;

    final initials = (name?.isNotEmpty == true)
        ? name!
            .split(' ')
            .where((w) => w.isNotEmpty)
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join()
        : (email?.isNotEmpty == true ? email![0].toUpperCase() : '?');

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppColors.darkSurfaceHigh,
                  AppColors.darkSurface,
                ]
              : [
                  AppColors.dustyTealLight.withValues(alpha: 0.4),
                  AppColors.pureWhite,
                ],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.dustyTeal,
                  AppColors.dustyTeal.withValues(alpha: 0.75),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.dustyTeal.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  fontFamily: 'Sora',
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: AppColors.pureWhite,
                ),
              ),
            ),
          ),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name?.isNotEmpty == true ? name! : l10n.displayUser,
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Gap(2),
                Text(
                  email ?? '',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colors.onSurface.withValues(alpha: 0.5),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label,
        style: context.textTheme.labelSmall?.copyWith(
          color: context.colors.onSurface.withValues(alpha: 0.45),
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Edit name bottom sheet ────────────────────────────────────────────────────

class _EditNameSheet extends ConsumerStatefulWidget {
  const _EditNameSheet({required this.currentName, required this.onSaved});
  final String? currentName;
  final VoidCallback onSaved;

  @override
  ConsumerState<_EditNameSheet> createState() => _EditNameSheetState();
}

class _EditNameSheetState extends ConsumerState<_EditNameSheet> {
  late final TextEditingController _controller;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(supabaseClientProvider).auth.updateUser(
            UserAttributes(data: {'name': name}),
          );
      ref.invalidate(currentUserProvider);
      widget.onSaved();
    } catch (e) {
      if (mounted) setState(() => _error = l10n.errorSavingName);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.editName, style: context.textTheme.titleLarge),
        const Gap(20),
        TextField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: l10n.fullName,
            prefixIcon: const Icon(Icons.person_outline),
          ),
          onSubmitted: (_) => _save(),
        ),
        if (_error != null) ...[
          const Gap(8),
          Text(
            _error!,
            style: TextStyle(color: context.colors.error, fontSize: 12),
          ),
        ],
        const Gap(20),
        FilledButton(
          onPressed: _loading ? null : _save,
          child: _loading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(l10n.save),
        ),
      ],
    );
  }
}

// ── Promo code dialog ─────────────────────────────────────────────────────────

class _PromoCodeDialog extends ConsumerStatefulWidget {
  const _PromoCodeDialog();

  @override
  ConsumerState<_PromoCodeDialog> createState() => _PromoCodeDialogState();
}

class _PromoCodeDialogState extends ConsumerState<_PromoCodeDialog> {
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
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.proPromoSuccess),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on PromoCodeException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() { _error = l10n.proPromoUnexpectedError; _loading = false; });
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
              prefixIcon: const Icon(Icons.local_offer_outlined),
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
                  fontFamily: 'Sora',
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
