import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_client.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/extensions.dart';
import '../../auth/presentation/providers/auth_provider.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isDark = ref.watch(
      themeModeProvider.select((v) => v.valueOrNull == ThemeMode.dark),
    );

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────────
            _DrawerHeader(user: user),
            const Divider(height: 1),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // ── Ajustes de usuario ─────────────────────────────────────
                  const _SectionLabel('Ajustes de usuario'),
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Nombre de usuario'),
                    subtitle: Text(
                      user?.name?.isNotEmpty == true
                          ? user!.name!
                          : 'Sin nombre',
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => _showEditNameSheet(
                      context,
                      ref,
                      user?.name,
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.email_outlined),
                    title: const Text('Email'),
                    subtitle: Text(user?.email ?? ''),
                  ),
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('Cambiar contraseña'),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => _confirmChangePassword(
                      context,
                      ref,
                      user?.email,
                    ),
                  ),
                  const Gap(8),

                  // ── Ajustes de la app ──────────────────────────────────────
                  const _SectionLabel('Ajustes de la app'),
                  SwitchListTile(
                    secondary: Icon(
                      isDark
                          ? Icons.dark_mode_outlined
                          : Icons.light_mode_outlined,
                    ),
                    title: const Text('Modo oscuro'),
                    value: isDark,
                    onChanged: (_) =>
                        ref.read(themeModeProvider.notifier).toggle(),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // ── Logout ────────────────────────────────────────────────────────
            ListTile(
              leading: Icon(
                Icons.logout_outlined,
                color: context.colors.error,
              ),
              title: Text(
                'Cerrar sesión',
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

  Future<void> _confirmChangePassword(
    BuildContext context,
    WidgetRef ref,
    String? email,
  ) async {
    if (email == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambiar contraseña'),
        content: Text(
          'Te enviaremos un enlace de cambio de contraseña a:\n\n$email',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(supabaseClientProvider).auth.resetPasswordForEmail(email);
      if (!context.mounted) return;
      Navigator.of(context).pop(); // cierra el drawer
      context.showSnackbar('Revisa tu email para cambiar la contraseña');
    } catch (_) {
      if (!context.mounted) return;
      context.showSnackbar('No se pudo enviar el email. Intenta de nuevo.', isError: true);
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
            Navigator.of(context).pop(); // close drawer too
          },
        ),
      ),
    );
  }
}

// ── Drawer header ──────────────────────────────────────────────────────────────

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.user});
  final dynamic user;

  @override
  Widget build(BuildContext context) {
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(
              initials,
              style: const TextStyle(
                fontFamily: 'Sora',
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: AppColors.primary,
              ),
            ),
          ),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name?.isNotEmpty == true ? name! : 'Usuario',
                  style: context.textTheme.titleMedium,
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

// ── Section label ──────────────────────────────────────────────────────────────

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

// ── Edit name bottom sheet ─────────────────────────────────────────────────────

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
      setState(() => _error = 'No se pudo guardar. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Editar nombre', style: context.textTheme.titleLarge),
        const Gap(20),
        TextField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nombre completo',
            prefixIcon: Icon(Icons.person_outline),
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
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
