import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import 'package:expense_manager/core/providers/app_lock_provider.dart';
import 'package:expense_manager/core/services/biometric_auth_service.dart';
import 'package:expense_manager/core/utils/extensions.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

/// Overlay opaco de bloqueo de la app. Montado en el `builder` de
/// `MaterialApp.router` (por encima del Navigator) para cubrir cualquier ruta
/// o diálogo sin desmontar el árbol — el estado del router sobrevive al
/// bloqueo. Bloquea al arrancar y al volver de background si el app lock está
/// activado ([appLockProvider]).
class LockGate extends ConsumerStatefulWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<LockGate>
    with WidgetsBindingObserver {
  bool _locked = false;
  // El prompt biométrico provoca pausas/resumes de la propia app (el diálogo
  // del sistema cubre la activity en Android); este flag evita re-bloquear o
  // re-lanzar el prompt por esos eventos de ciclo de vida.
  bool _authInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lockOnLaunch();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _lockOnLaunch() async {
    bool enabled;
    try {
      enabled = await ref.read(appLockProvider.future);
    } catch (_) {
      // Prefs ilegibles: no dejar al usuario fuera de la app.
      enabled = false;
    }
    if (!enabled || !mounted) return;
    setState(() => _locked = true);
    unawaited(_authenticate());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_locked && !_authInProgress) _authenticate();
    } else if (state == AppLifecycleState.paused) {
      if (_authInProgress || _locked) return;
      final enabled = ref.read(appLockProvider).value ?? false;
      if (enabled) setState(() => _locked = true);
    }
  }

  Future<void> _authenticate() async {
    if (_authInProgress || !mounted) return;
    _authInProgress = true;
    try {
      final l10n = AppLocalizations.of(context);
      final ok = await ref
          .read(biometricAuthServiceProvider)
          .authenticate(l10n.appLockUnlockReason);
      if (ok && mounted) setState(() => _locked = false);
    } finally {
      _authInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_locked) return widget.child;

    final l10n = AppLocalizations.of(context);
    final cs = context.colors;
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          // Material opaco: oculta los datos financieros también en la
          // miniatura del app switcher.
          child: Material(
            color: cs.surface,
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: context.appColors.raised,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          PhosphorIcons.lock(),
                          size: 28,
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const Gap(20),
                      Text(
                        l10n.appLock,
                        textAlign: TextAlign.center,
                        style: context.textTheme.titleMedium?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Gap(24),
                      FilledButton.icon(
                        onPressed: _authenticate,
                        icon: Icon(PhosphorIcons.fingerprint(), size: 20),
                        label: Text(l10n.unlock),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
