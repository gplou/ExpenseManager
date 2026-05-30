import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';

import '../../../../core/config/router.dart';
import '../../../../core/errors/failure_localizations.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);

    final success = await ref.read(authProvider.notifier).signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          name: _nameController.text.trim(),
        );

    if (success && mounted) {
      context.showSnackbar(l10n.accountCreated);
      context.go(AppRoutes.dashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authProvider);
    final isLoading = authState is Loading;

    ref.listen(authProvider, (_, next) {
      if (next is Failure) {
        context.showSnackbar(next.failure.localizedMessage(l10n), isError: true);
        ref.read(authProvider.notifier).reset();
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.createAccount,
                    style: context.textTheme.headlineMedium),
                const Gap(8),
                Text(
                  l10n.registerSubtitle,
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: context.colors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const Gap(40),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l10n.nameLabel,
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? l10n.enterName : null,
                ),
                const Gap(16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l10n.emailLabel,
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return l10n.enterEmail;
                    if (!v.isValidEmail) return l10n.invalidEmail;
                    return null;
                  },
                ),
                const Gap(16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleRegister(),
                  decoration: InputDecoration(
                    labelText: l10n.passwordLabel,
                    prefixIcon: const Icon(Icons.lock_outlined),
                    helperText: l10n.passwordMinChars,
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword
                          ? l10n.showPassword
                          : l10n.hidePassword,
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return l10n.enterPasswordRequired;
                    if (!v.isValidPassword) return l10n.passwordTooShort;
                    return null;
                  },
                ),
                const Gap(32),
                ElevatedButton(
                  onPressed: isLoading ? null : _handleRegister,
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(l10n.createAccount),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
