import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/widget_action_provider.dart';
import '../../../core/services/image_input_gateway.dart';
import '../../../core/services/voice_input_gateway.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/widgets/neo_card.dart';
import '../../../l10n/app_localizations.dart';
import '../../subscription/subscription_provider.dart';
import '../../subscription/subscription_state.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/services/analytics_service.dart';
import '../../transactions/data/image_transaction_parser.dart';
import '../../transactions/data/voice_transaction_parser.dart';
import '../../transactions/domain/parsed_voice_transaction.dart';
import '../../transactions/presentation/screens/add_transaction_screen.dart';
import '../../tutorial/tutorial_keys.dart';
import '../../tutorial/tutorial_notifier.dart';

enum VoiceInputState { idle, listening, processing, cameraProcessing }

/// Floating "+" button rendered at the bottom-center of the dashboard.
///
/// Tapping it opens the [AddTransactionScreen] bottom sheet, which contains
/// the voice / photo / manual entry points. This widget keeps the voice and
/// camera processing logic only because the home-screen widget can deep-link
/// directly into voice/photo capture without going through the sheet.
class SpeedDialFab extends ConsumerStatefulWidget {
  const SpeedDialFab({super.key});

  @override
  ConsumerState<SpeedDialFab> createState() => _SpeedDialFabState();
}

class _SpeedDialFabState extends ConsumerState<SpeedDialFab> {
  VoiceInputState _voiceState = VoiceInputState.idle;
  bool _handledInitialWidgetAction = false;

  late final VoiceInputGateway _speech;
  late final VoiceTransactionParser _parser;
  late final ImageInputGateway _imagePicker;
  late final ImageTransactionParser _imageParser;

  static const double _fabSize = 64;
  static const double _miniFabSize = 48;
  static const double _clusterSpacing = 24;

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

  static String _speechLocaleId(String langCode) => switch (langCode) {
    'es' => 'es_ES',
    'en' => 'en_US',
    'fr' => 'fr_FR',
    'de' => 'de_DE',
    _ => 'en_US',
  };

  bool _requirePro() {
    if (ref.read(isProProvider)) return true;
    context.push(AppRoutes.pro);
    return false;
  }

  Future<void> _handleWidgetAction(String action) async {
    // Wait for subscription to finish loading before gating on pro status
    // (cold-start from widget would otherwise always see isPro == false).
    if (ref.read(subscriptionProvider).isLoading) {
      await ref.read(subscriptionProvider.future).catchError((_) => const SubscriptionState());
    }
    if (!mounted) return;

    if (action == WidgetActions.voice) {
      if (!_requirePro()) return;
      _startVoice();
    } else if (action == WidgetActions.add) {
      showAddTransactionSheet(context);
    } else if (action == WidgetActions.chat) {
      if (!_requirePro()) return;
      context.push(AppRoutes.chat);
    } else if (action == WidgetActions.photo) {
      if (!_requirePro()) return;
      _startCamera();
    }
  }

  void _openAddSheet() {
    HapticFeedback.lightImpact();
    showAddTransactionSheet(context);
  }

  void _onTapVoice() {
    if (!_requirePro()) return;
    _startVoice();
  }

  void _onTapPhoto() {
    if (!_requirePro()) return;
    _startCamera();
  }

  Future<void> _startVoice() async {
    final available = await _speech.initialize(
      onError: (_) {
        if (mounted) setState(() => _voiceState = VoiceInputState.idle);
      },
    );

    if (!available) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.micUnavailable)),
        );
      }
      return;
    }

    setState(() => _voiceState = VoiceInputState.listening);
    AnalyticsService.track(AnalyticsService.voiceUsed);

    final langCode = ref.read(localeProvider).value?.languageCode ?? 'es';
    await _speech.listen(
      localeId: _speechLocaleId(langCode),
      onResult: (result) {
        if (result.finalResult) _processVoice(result.recognizedWords);
      },
    );
  }

  Future<void> _processVoice(String text) async {
    if (text.trim().isEmpty) {
      if (mounted) setState(() => _voiceState = VoiceInputState.idle);
      return;
    }
    setState(() => _voiceState = VoiceInputState.processing);
    ParsedVoiceTransaction? parsed;
    try {
      parsed = await _parser.parse(text);
    } catch (e) {
      if (!mounted) return;
      setState(() => _voiceState = VoiceInputState.idle);
      final info = e.toString().split('\n').first;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.voiceAiError(e.runtimeType.toString(), info))),
      );
      return;
    }
    if (!mounted) return;
    if (parsed == null) {
      setState(() => _voiceState = VoiceInputState.idle);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).voiceInterpretError),
        ),
      );
      return;
    }
    await _speech.stop();
    setState(() => _voiceState = VoiceInputState.idle);
    if (!mounted) return;
    showAddTransactionSheet(context, voiceData: parsed);
  }

  Future<void> _startCamera() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: Text(l10n.cameraOption),
                  onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: Text(l10n.galleryOption),
                  onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
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
      final imageBytes = await tempFile.readAsBytes();

      final ParsedVoiceTransaction? parsed = await _imageParser.parse(imageBytes);

      if (!mounted) return;
      setState(() => _voiceState = VoiceInputState.idle);

      if (parsed == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).imageTransactionNotDetected),
          ),
        );
        return;
      }
      showAddTransactionSheet(context, voiceData: parsed);
    } catch (e) {
      if (mounted) {
        setState(() => _voiceState = VoiceInputState.idle);
        final info = e.toString().split('\n').first;
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.imageAiError(e.runtimeType.toString(), info))),
        );
      }
    } finally {
      try {
        if (tempFile != null && await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
    }
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

    final l10n = AppLocalizations.of(context);
    final fabBottom = MediaQuery.of(context).padding.bottom + 16.0;

    // Report the FAB rect so the tutorial overlay can draw its spotlight
    // without relying on GlobalKey measurement through nested Stacks.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bodyBox = context.findRenderObject() as RenderBox?;
      if (bodyBox == null || !bodyBox.hasSize) return;
      final bodyOrigin = bodyBox.localToGlobal(Offset.zero);
      final bodySize = bodyBox.size;
      final fabX = bodyOrigin.dx + (bodySize.width - _fabSize) / 2;
      final fabY = bodyOrigin.dy + bodySize.height - fabBottom - _fabSize;
      final newRect = Rect.fromLTWH(fabX, fabY, _fabSize, _fabSize);
      if (ref.read(fabRectProvider) != newRect) {
        ref.read(fabRectProvider.notifier).state = newRect;
      }
    });

    if (_voiceState != VoiceInputState.idle) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            bottom: fabBottom,
            left: 0,
            right: 0,
            child: Center(child: _buildVoiceWidget()),
          ),
        ],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          bottom: fabBottom,
          left: 0,
          right: 0,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _MiniFab(
                  icon: Icons.mic_rounded,
                  label: l10n.labelVoice,
                  hint: l10n.voiceHintStartListening,
                  onTap: _onTapVoice,
                ),
                const SizedBox(width: _clusterSpacing),
                Semantics(
                  button: true,
                  label: l10n.fabOpenMenu,
                  child: SizedBox(
                    key: TutorialKeys.fabKey,
                    width: _fabSize,
                    height: _fabSize,
                    child: NeoFab(
                      icon: Icons.add,
                      onTap: _openAddSheet,
                    ),
                  ),
                ),
                const SizedBox(width: _clusterSpacing),
                _MiniFab(
                  icon: Icons.camera_alt_rounded,
                  label: l10n.labelPhoto,
                  hint: l10n.photoHintStartCamera,
                  onTap: _onTapPhoto,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceWidget() {
    const fabSize = _fabSize;
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
          width: fabSize,
          height: fabSize,
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
          width: fabSize,
          height: fabSize,
          decoration: const BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.stop_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

class _MiniFab extends StatefulWidget {
  const _MiniFab({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  State<_MiniFab> createState() => _MiniFabState();
}

class _MiniFabState extends State<_MiniFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _scale = Tween(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    HapticFeedback.lightImpact();
    await _ctrl.forward();
    await _ctrl.reverse();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? AppColors.dustyTeal.withValues(alpha: 0.22)
        : AppColors.dustyTealLight;
    return Semantics(
      button: true,
      label: widget.label,
      hint: widget.hint,
      child: Tooltip(
        message: widget.label,
        child: SizedBox(
          width: _SpeedDialFabState._miniFabSize,
          height: _SpeedDialFabState._miniFabSize,
          child: GestureDetector(
            onTap: _handleTap,
            child: ScaleTransition(
              scale: _scale,
              child: Container(
                decoration: BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                  boxShadow: isDark
                      ? null
                      : AppElevation.tinted(
                          AppColors.dustyTeal,
                          opacity: 0.14,
                        ),
                ),
                child: Icon(
                  widget.icon,
                  color: AppColors.dustyTeal,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
