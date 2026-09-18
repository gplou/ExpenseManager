import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

import 'package:expense_manager/core/config/router.dart';
import 'package:expense_manager/core/constants/app_constants.dart';
import 'package:expense_manager/core/providers/locale_provider.dart';
import 'package:expense_manager/core/providers/widget_action_provider.dart';
import 'package:expense_manager/core/services/analytics_service.dart';
import 'package:expense_manager/core/services/image_input_gateway.dart';
import 'package:expense_manager/core/services/sentry_service.dart';
import 'package:expense_manager/core/services/voice_input_gateway.dart';
import 'package:expense_manager/core/theme/app_colors.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/features/subscription/subscription_state.dart';
import 'package:expense_manager/features/transactions/data/image_transaction_parser.dart';
import 'package:expense_manager/features/transactions/data/voice_transaction_parser.dart';
import 'package:expense_manager/features/transactions/domain/parsed_voice_transaction.dart';
import 'package:expense_manager/features/transactions/presentation/providers/subcategories_provider.dart';
import 'package:expense_manager/features/transactions/presentation/screens/add_transaction_screen.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

enum VoiceInputState { idle, listening, processing, cameraProcessing }

/// Acciones de captura rápida, accesibles desde cualquier punto del árbol.
///
/// Se expone como `InheritedWidget` y no como provider porque [QuickCaptureHost]
/// se monta por encima del Navigator: así lo alcanzan tanto la barra inferior
/// como las hojas modales, que son rutas hijas de ese Navigator.
class QuickCapture extends InheritedWidget {
  const QuickCapture({
    super.key,
    required this.startVoice,
    required this.startPhoto,
    required this.openAddSheet,
    required super.child,
  });

  final VoidCallback startVoice;
  final VoidCallback startPhoto;
  final VoidCallback openAddSheet;

  static QuickCapture? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<QuickCapture>();

  @override
  bool updateShouldNotify(QuickCapture oldWidget) => false;
}

/// Dueño del pipeline de voz e imagen y del despacho de acciones del widget
/// de pantalla de inicio.
///
/// Vive por encima del Navigator (en el `builder` de MaterialApp) por dos
/// motivos: sigue vivo al cambiar de pestaña —los deep links
/// `expensemanager://widget/*` pueden llegar en cualquier momento— y queda al
/// alcance de las hojas modales, que necesitan los accesos de voz y foto.
class QuickCaptureHost extends ConsumerStatefulWidget {
  const QuickCaptureHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<QuickCaptureHost> createState() => _QuickCaptureHostState();
}

class _QuickCaptureHostState extends ConsumerState<QuickCaptureHost> {
  VoiceInputState _voiceState = VoiceInputState.idle;
  bool _handledInitialWidgetAction = false;

  late final VoiceInputGateway _speech;
  late final VoiceTransactionParser _parser;
  late final ImageInputGateway _imagePicker;
  late final ImageTransactionParser _imageParser;

  static const double _overlaySize = 64;

  @override
  void initState() {
    super.initState();
    _speech = ref.read(voiceInputGatewayProvider);
    _imagePicker = ref.read(imageInputGatewayProvider);
    _parser = ref.read(voiceTransactionParserProvider);
    _imageParser = ref.read(imageTransactionParserProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _handledInitialWidgetAction) return;
      final action = ref.read(pendingWidgetActionProvider);
      if (action != null) {
        _handledInitialWidgetAction = true;
        _handleWidgetAction(action);
        ref.read(pendingWidgetActionProvider.notifier).state = null;
      }
    });
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  // ── Acceso al Navigator raíz ─────────────────────────────────────────────
  //
  // El contexto propio de este widget queda POR ENCIMA del Navigator, así que
  // `Navigator.of` no lo encontraría. Todo lo que necesite un contexto pasa
  // por estos helpers, que lo resuelven desde la GlobalKey en el momento de
  // usarlo: nunca se guarda un contexto entre awaits.

  void _showSnack(String Function(AppLocalizations l10n) message) {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(content: Text(message(AppLocalizations.of(ctx)))),
    );
  }

  void _openSheet({ParsedVoiceTransaction? voiceData}) {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    showAddTransactionSheet(ctx, voiceData: voiceData).ignore();
  }

  void _pushRoute(String path) {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    ctx.push(path).ignore();
  }

  bool _requirePro() {
    if (ref.read(isProProvider)) return true;
    _pushRoute(AppRoutes.pro);
    return false;
  }

  Future<void> _handleWidgetAction(String action) async {
    // Espera a que la suscripción termine de cargar antes de aplicar el gate
    // PRO (en arranque en frío desde el widget, isPro sería siempre false).
    if (ref.read(subscriptionProvider).isLoading) {
      await ref
          .read(subscriptionProvider.future)
          .catchError((_) => const SubscriptionState());
    }
    if (!mounted) return;

    if (action == WidgetActions.voice) {
      if (!_requirePro()) return;
      _startVoice().ignore();
    } else if (action == WidgetActions.add) {
      _openAddSheet();
    } else if (action == WidgetActions.chat) {
      if (!_requirePro()) return;
      _pushRoute(AppRoutes.chat);
    } else if (action == WidgetActions.photo) {
      if (!_requirePro()) return;
      _startCamera().ignore();
    }
  }

  void _openAddSheet() => _openSheet();

  void _onTapVoice() {
    if (!_requirePro()) return;
    _startVoice();
  }

  void _onTapPhoto() {
    if (!_requirePro()) return;
    _startCamera();
  }

  /// `speech_to_text` keeps calling this for the lifetime of the recognizer,
  /// not just during `initialize()` — most notably for "no speech"/"no
  /// match" once listening has started, which previously reset the voice
  /// state silently with no feedback at all.
  void _handleVoiceError(SpeechRecognitionError error) {
    if (!mounted) return;
    setState(() => _voiceState = VoiceInputState.idle);
    _showSnack((l10n) => error.permanent ? l10n.micUnavailable : l10n.voiceInterpretError);
  }

  Future<void> _startVoice() async {
    final available = await _speech.initialize(onError: _handleVoiceError);

    if (!available) {
      _showSnack((l10n) => l10n.micUnavailable);
      return;
    }

    setState(() => _voiceState = VoiceInputState.listening);
    AnalyticsService.track(AnalyticsService.voiceUsed);

    final langCode = ref.read(localeProvider).value?.languageCode ?? 'es';
    try {
      await _speech.listen(
        localeId: VoiceInputGateway.localeIdFor(langCode),
        onResult: (result) {
          if (result.finalResult) _processVoice(result.recognizedWords);
        },
      );
    } catch (e, st) {
      // El reconocedor puede dejar de estar disponible entre initialize() y
      // listen() (servicio del sistema caído, permiso revocado, etc.).
      unawaited(SentryService.captureException(e, stackTrace: st));
      if (!mounted) return;
      setState(() => _voiceState = VoiceInputState.idle);
      _showSnack((l10n) => l10n.micUnavailable);
    }
  }

  Future<void> _processVoice(String text) async {
    if (text.trim().isEmpty) {
      if (mounted) setState(() => _voiceState = VoiceInputState.idle);
      return;
    }
    setState(() => _voiceState = VoiceInputState.processing);
    ParsedVoiceTransaction? parsed;
    try {
      final subcats = ref.read(allSubcategoriesProvider).value ?? const [];
      final langCode = ref.read(localeProvider).value?.languageCode ?? 'es';
      parsed = await _parser.parse(
        text,
        langCode: langCode,
        subcategories: subcats,
      );
    } catch (e, st) {
      // El detalle técnico va a Sentry; al usuario solo un mensaje accionable.
      unawaited(SentryService.captureException(e, stackTrace: st));
      if (!mounted) return;
      setState(() => _voiceState = VoiceInputState.idle);
      _showSnack((l10n) => l10n.aiProcessingError);
      return;
    }
    if (!mounted) return;
    if (parsed == null) {
      setState(() => _voiceState = VoiceInputState.idle);
      _showSnack((l10n) => l10n.voiceInterpretError);
      return;
    }
    await _speech.stop();
    setState(() => _voiceState = VoiceInputState.idle);
    _openSheet(voiceData: parsed);
  }

  Future<void> _startCamera() async {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: ctx,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        final l10n = AppLocalizations.of(sheetCtx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(PhosphorIcons.camera()),
                  title: Text(l10n.cameraOption),
                  onTap: () => Navigator.of(sheetCtx).pop(ImageSource.camera),
                ),
                ListTile(
                  leading: Icon(PhosphorIcons.imagesSquare()),
                  title: Text(l10n.galleryOption),
                  onTap: () => Navigator.of(sheetCtx).pop(ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null || !mounted) return;

    final XFile? picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (picked == null || !mounted) return;
    AnalyticsService.track(AnalyticsService.photoUsed, {'source': source.name});
    await _processImage(picked);
  }

  Future<void> _processImage(XFile pickedFile) async {
    if (!mounted) return;
    setState(() => _voiceState = VoiceInputState.cameraProcessing);

    File? tempFile;
    try {
      tempFile = File(pickedFile.path);

      final ParsedVoiceTransaction? parsed =
          await _imageParser.parse(pickedFile.path);

      if (!mounted) return;
      setState(() => _voiceState = VoiceInputState.idle);

      if (parsed == null) {
        _showSnack((l10n) => l10n.imageTransactionNotDetected);
        return;
      }
      _openSheet(voiceData: parsed);
    } catch (e, st) {
      // El detalle técnico va a Sentry; al usuario solo un mensaje accionable.
      unawaited(SentryService.captureException(e, stackTrace: st));
      if (mounted) {
        setState(() => _voiceState = VoiceInputState.idle);
        _showSnack((l10n) => l10n.aiProcessingError);
      }
    } finally {
      try {
        if (tempFile != null && await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
    }
  }

  Widget _buildOverlay(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_voiceState == VoiceInputState.processing ||
        _voiceState == VoiceInputState.cameraProcessing) {
      final label = _voiceState == VoiceInputState.cameraProcessing
          ? l10n.imageProcessing
          : l10n.voiceProcessing;
      return Semantics(
        label: label,
        liveRegion: true,
        excludeSemantics: true,
        child: Container(
          width: _overlaySize,
          height: _overlaySize,
          decoration: const BoxDecoration(
            color: AppColors.dustyTeal,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
    }
    return Semantics(
      button: true,
      label: l10n.voiceListening,
      child: GestureDetector(
        onTap: () async {
          await _speech.stop();
          if (mounted) setState(() => _voiceState = VoiceInputState.idle);
        },
        child: Container(
          width: _overlaySize,
          height: _overlaySize,
          decoration: const BoxDecoration(
            // Rojo de grabación: convención universal de UI (recording),
            // intencionadamente distinto del coral AppColors.negative ('gasto').
            color: Colors.red,
            shape: BoxShape.circle,
          ),
          child: Icon(PhosphorIcons.stop(), color: Colors.white, size: 28),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(pendingWidgetActionProvider, (_, action) {
      if (action == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _handleWidgetAction(action);
        ref.read(pendingWidgetActionProvider.notifier).state = null;
      });
    });

    return QuickCapture(
      startVoice: _onTapVoice,
      startPhoto: _onTapPhoto,
      openAddSheet: _openAddSheet,
      child: Stack(
        children: [
          widget.child,
          if (_voiceState != VoiceInputState.idle)
            Positioned(
              bottom: MediaQuery.paddingOf(context).bottom + 96,
              left: 0,
              right: 0,
              child: Center(child: _buildOverlay(context)),
            ),
        ],
      ),
    );
  }
}
