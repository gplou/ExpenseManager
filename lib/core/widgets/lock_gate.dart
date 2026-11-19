import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import 'package:expense_manager/core/providers/app_lock_provider.dart';
import 'package:expense_manager/core/services/biometric_auth_service.dart';
import 'package:expense_manager/core/services/external_activity_guard.dart';
import 'package:expense_manager/core/utils/extensions.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

/// Overlay opaco de bloqueo de la app. Montado en el `builder` de
/// `MaterialApp.router` (por encima del Navigator) para cubrir cualquier ruta
/// o diálogo sin desmontar el árbol — el estado del router sobrevive al
/// bloqueo. Bloquea al arrancar y al volver de background si el app lock está
/// activado ([appLockProvider]), salvo cuando el background lo causa una
/// pantalla externa abierta por la propia app ([ExternalActivityGuard]).
///
/// Mientras está bloqueado, el contenido de debajo sigue montado pero queda
/// fuera del árbol de semántica, del foco y de los punteros: el overlay opaco
/// solo lo oculta a la vista, y sin esto TalkBack/VoiceOver (o cualquier
/// servicio de accesibilidad) seguiría leyendo los importes, y un teclado
/// abierto seguiría escribiendo en el campo enfocado de detrás.
class LockGate extends ConsumerStatefulWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  /// `true` mientras la app está bloqueada o aún no se sabe si debe estarlo
  /// (arranque, antes de leer la preferencia). `null` fuera de un [LockGate].
  ///
  /// Lo usa la captura rápida para no abrir el micrófono/cámara ni hojas con
  /// datos por un deep link del widget antes de que el usuario se autentique.
  static ValueListenable<bool>? maybeCoverOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_LockScope>()?.covered;

  /// Completa en cuanto la app está desbloqueada (inmediatamente si ya lo
  /// está o si no hay [LockGate] por encima).
  static Future<void> waitUntilUnlocked(BuildContext context) {
    final covered = maybeCoverOf(context);
    if (covered == null || !covered.value) return Future.value();
    final completer = Completer<void>();
    void listener() {
      if (covered.value) return;
      covered.removeListener(listener);
      completer.complete();
    }

    covered.addListener(listener);
    return completer.future;
  }

  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

class _LockScope extends InheritedWidget {
  const _LockScope({required this.covered, required super.child});

  final ValueListenable<bool> covered;

  // La instancia del notifier no cambia nunca: quien la necesite escucha.
  @override
  bool updateShouldNotify(_LockScope oldWidget) => false;
}

class _LockGateState extends ConsumerState<LockGate>
    with WidgetsBindingObserver {
  bool _locked = false;
  // `_locked` o "aún no se ha leído la preferencia" (ver [LockGate.maybeCoverOf]).
  final ValueNotifier<bool> _covered = ValueNotifier(true);
  // El prompt biométrico provoca pausas/resumes de la propia app (el diálogo
  // del sistema cubre la activity en Android); este flag evita re-bloquear o
  // re-lanzar el prompt por esos eventos de ciclo de vida.
  bool _authInProgress = false;
  // Momento de una pausa causada por una pantalla externa abierta a propósito
  // (ver [ExternalActivityGuard]): no bloquea salvo que la vuelta tarde más
  // de [ExternalActivityGuard.maxDuration].
  DateTime? _externalPauseAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lockOnLaunch();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _covered.dispose();
    super.dispose();
  }

  void _setLocked(bool locked) {
    setState(() => _locked = locked);
    _covered.value = locked;
  }

  Future<void> _lockOnLaunch() async {
    bool enabled;
    try {
      enabled = await ref.read(appLockProvider.future);
    } catch (_) {
      // Prefs ilegibles: no dejar al usuario fuera de la app.
      enabled = false;
    }
    if (!mounted) return;
    if (!enabled) {
      _covered.value = false;
      return;
    }
    _setLocked(true);
    unawaited(_authenticate());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final externalPauseAt = _externalPauseAt;
      _externalPauseAt = null;
      if (externalPauseAt != null &&
          !_locked &&
          clock.now().difference(externalPauseAt) >
              ExternalActivityGuard.maxDuration) {
        _setLocked(true);
      }
      if (_locked && !_authInProgress) _authenticate();
    } else if (state == AppLifecycleState.paused) {
      if (_authInProgress || _locked) return;
      final enabled = ref.read(appLockProvider).value ?? false;
      if (!enabled) return;
      if (ExternalActivityGuard.isActive) {
        _externalPauseAt ??= clock.now();
        return;
      }
      _setLocked(true);
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
      if (ok && mounted) _setLocked(false);
    } finally {
      _authInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Estructura estable (bloqueado o no): el subárbol del child no se
    // desmonta al bloquear. `passthrough` le da las mismas constraints que
    // tendría sin el Stack.
    return _LockScope(
      covered: _covered,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          ExcludeFocus(
            excluding: _locked,
            child: ExcludeSemantics(
              excluding: _locked,
              child: IgnorePointer(ignoring: _locked, child: widget.child),
            ),
          ),
          if (_locked) _buildOverlay(context),
        ],
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = context.colors;
    return Positioned.fill(
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
                      PhosphorIcons.lock,
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
                    icon: Icon(PhosphorIcons.fingerprint, size: 20),
                    label: Text(l10n.unlock),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
