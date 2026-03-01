import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';

import '../../../../core/config/router.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authNotifierProvider.notifier).signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    if (success && mounted) {
      context.go(AppRoutes.dashboard);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final success =
        await ref.read(authNotifierProvider.notifier).signInWithGoogle();
    if (success && mounted) {
      context.go(AppRoutes.dashboard);
    }
  }

  Future<void> _handleAppleSignIn() async {
    final success =
        await ref.read(authNotifierProvider.notifier).signInWithApple();
    if (success && mounted) {
      context.go(AppRoutes.dashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState is Loading;

    ref.listen(authNotifierProvider, (_, next) {
      if (next is Failure) {
        context.showSnackbar(next.failure.userMessage, isError: true);
        ref.read(authNotifierProvider.notifier).reset();
      }
    });

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Gap(48),
                Text(
                  l10n.welcome,
                  style: context.textTheme.headlineMedium,
                ),
                const Gap(8),
                Text(
                  l10n.loginSubtitle,
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: context.colors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const Gap(48),
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
                  onFieldSubmitted: (_) => _handleLogin(),
                  decoration: InputDecoration(
                    labelText: l10n.passwordLabel,
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
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
                    if (v == null || v.isEmpty) return l10n.enterPassword;
                    return null;
                  },
                ),
                const Gap(8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: Text(l10n.forgotPassword),
                  ),
                ),
                const Gap(24),
                ElevatedButton(
                  onPressed: isLoading ? null : _handleLogin,
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(l10n.signIn),
                ),
                const Gap(32),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        l10n.orContinueWith,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colors.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const Gap(24),
                _SocialButton(
                  onPressed: isLoading ? null : _handleGoogleSignIn,
                  icon: _GoogleIcon(),
                  label: l10n.continueWithGoogle,
                ),
                if (Platform.isIOS || Platform.isMacOS) ...[
                  const Gap(12),
                  _SocialButton(
                    onPressed: isLoading ? null : _handleAppleSignIn,
                    icon: const Icon(Icons.apple, size: 22),
                    label: l10n.continueWithApple,
                  ),
                ],
                const Gap(24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l10n.noAccount,
                      style: context.textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () => context.push(AppRoutes.register),
                      child: Text(l10n.signUp),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon,
        label: Text(label),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: context.colors.outline.withValues(alpha: 0.5),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 22,
      height: 22,
      child: _GoogleLetterG(),
    );
  }
}

class _GoogleLetterG extends StatelessWidget {
  const _GoogleLetterG();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GoogleGPainter());
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    _drawArc(canvas, center, radius, 210 * (3.14159 / 180),
        240 * (3.14159 / 180), const Color(0xFF4285F4));
    _drawArc(canvas, center, radius, 90 * (3.14159 / 180),
        120 * (3.14159 / 180), const Color(0xFFEA4335));
    _drawArc(canvas, center, radius, 210 * (3.14159 / 180),
        60 * (3.14159 / 180), const Color(0xFFFBBC05));
    _drawArc(canvas, center, radius, 270 * (3.14159 / 180),
        60 * (3.14159 / 180), const Color(0xFF34A853));

    final paint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(center.dx, center.dy - radius * 0.18,
          radius + 1, radius * 0.36),
      paint,
    );
  }

  void _drawArc(Canvas canvas, Offset center, double radius, double startAngle,
      double sweepAngle, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.28;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.86),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
