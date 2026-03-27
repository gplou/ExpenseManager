import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/config/router.dart';
import '../../../core/providers/widget_action_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/neo_card.dart';
import '../../../l10n/app_localizations.dart';
import '../../subscription/subscription_provider.dart';
import '../../transactions/data/image_transaction_parser.dart';
import '../../transactions/data/voice_transaction_parser.dart';
import '../../transactions/domain/parsed_voice_transaction.dart';
import '../../tutorial/tutorial_keys.dart';
import '../../tutorial/tutorial_notifier.dart';

enum VoiceInputState { idle, listening, processing, cameraProcessing }

class SpeedDialFab extends ConsumerStatefulWidget {
  const SpeedDialFab({super.key});

  @override
  ConsumerState<SpeedDialFab> createState() => _SpeedDialFabState();
}

class _SpeedDialFabState extends ConsumerState<SpeedDialFab> {
  bool _open = false;
  VoiceInputState _voiceState = VoiceInputState.idle;
  bool _handledInitialWidgetAction = false;

  final _speech = SpeechToText();
  late final VoiceTransactionParser _parser;
  final _imagePicker = ImagePicker();
  late final ImageTransactionParser _imageParser;

  @override
  void initState() {
    super.initState();
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

  bool _requirePro() {
    if (ref.read(isProProvider)) return true;
    _closeDial();
    context.push(AppRoutes.pro);
    return false;
  }

  void _handleWidgetAction(String action) {
    if (action == 'voice') {
      if (!_requirePro()) return;
      _startVoice();
    } else if (action == 'add') {
      context.push(AppRoutes.addTransaction);
    } else if (action == 'chat') {
      if (!_requirePro()) return;
      context.push(AppRoutes.chat);
    } else if (action == 'photo') {
      if (!_requirePro()) return;
      _startCamera();
    }
  }

  void _toggle() => setState(() => _open = !_open);

  void _closeDial() {
    if (_open) setState(() => _open = false);
  }

  Future<void> _startVoice() async {
    _closeDial();

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

    await _speech.listen(
      localeId: 'es_ES',
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
    context.push(AppRoutes.addTransaction, extra: parsed);
  }

  Future<void> _startCamera() async {
    _closeDial();

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
      context.push(AppRoutes.addTransaction, extra: parsed);
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

  // ── Layout constants ──────────────────────────────────────────────────────
  static const double _stackW   = 220;
  static const double _stackH   = 175;
  static const double _fabSize  =  64;
  static const double _miniSize =  50;

  static const double _fabCx = _stackW / 2;
  static const double _fabCy = _stackH - _fabSize / 2;

  static const Offset _micTarget    = Offset(33,  107);
  static const Offset _pencilTarget = Offset(110,  58);
  static const Offset _cameraTarget = Offset(187, 107);

  static const Offset _closedPos = Offset(_fabCx, _fabCy);

  static double _left(Offset c)   => c.dx - _miniSize / 2;
  static double _bottom(Offset c) => _stackH - c.dy - _miniSize / 2;

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

    final tutStep = ref.watch(
      tutorialProvider.select((s) => s.isActive ? s.stepIndex : -1),
    );
    final tutNeedsDialOpen = tutStep >= 1 && tutStep <= 3;
    if (tutNeedsDialOpen && !_open) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_open) setState(() => _open = true);
      });
    } else if (tutStep >= 4 && _open) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _open) setState(() => _open = false);
      });
    }

    final l10n = AppLocalizations.of(context);

    final fabBottom =
        MediaQuery.of(context).padding.bottom + 16.0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bodyBox = context.findRenderObject() as RenderBox?;
      if (bodyBox == null || !bodyBox.hasSize) return;
      final bodyOrigin = bodyBox.localToGlobal(Offset.zero);
      final bodySize = bodyBox.size;
      final fabX = bodyOrigin.dx + (bodySize.width - _fabSize) / 2;
      final fabY = bodyOrigin.dy + bodySize.height - fabBottom - _fabSize;
      ref.read(fabRectProvider.notifier).state =
          Rect.fromLTWH(fabX, fabY, _fabSize, _fabSize);
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
        IgnorePointer(
          ignoring: !_open,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _open ? 1.0 : 0.0,
            child: GestureDetector(
              onTap: _closeDial,
              behavior: HitTestBehavior.opaque,
              child: Container(
                color: Colors.black.withValues(alpha: 0.35),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: fabBottom,
          left: 0,
          right: 0,
          child: Center(
            child: SizedBox(
              width: _stackW,
              height: _stackH,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _radialButton(
                    context,
                    tutorialKey: TutorialKeys.voiceBtnKey,
                    icon: Icons.mic_outlined,
                    label: l10n.labelVoice,
                    target: _micTarget,
                    onTap: () {
                      if (!_requirePro()) return;
                      _startVoice();
                    },
                  ),
                  _radialButton(
                    context,
                    tutorialKey: TutorialKeys.manualBtnKey,
                    icon: Icons.edit_outlined,
                    label: l10n.labelManual,
                    target: _pencilTarget,
                    onTap: () {
                      _closeDial();
                      context.push(AppRoutes.addTransaction);
                    },
                  ),
                  _radialButton(
                    context,
                    tutorialKey: TutorialKeys.cameraBtnKey,
                    icon: Icons.camera_alt_outlined,
                    label: l10n.labelPhoto,
                    target: _cameraTarget,
                    onTap: () {
                      if (!_requirePro()) return;
                      _startCamera();
                    },
                  ),
                  Positioned(
                    left: (_stackW - _fabSize) / 2,
                    bottom: 0,
                    child: SizedBox(
                      key: TutorialKeys.fabKey,
                      width: _fabSize,
                      height: _fabSize,
                      child: NeoFab(
                        icon: _open ? Icons.close : Icons.add,
                        onTap: _toggle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _radialButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Offset target,
    required VoidCallback onTap,
    GlobalKey? tutorialKey,
  }) {
    final centre = _open ? target : _closedPos;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      left:   _left(centre),
      bottom: _bottom(centre),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _open ? 1.0 : 0.0,
        child: IgnorePointer(
          ignoring: !_open,
          child: _MiniDialButton(
            key: tutorialKey,
            icon: icon,
            label: label,
            onTap: onTap,
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceWidget() {
    const fabSize = _fabSize;
    if (_voiceState == VoiceInputState.processing ||
        _voiceState == VoiceInputState.cameraProcessing) {
      return Container(
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
      );
    }
    return GestureDetector(
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
    );
  }
}

class _MiniDialButton extends StatelessWidget {
  const _MiniDialButton({super.key, required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.dustyTeal,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.dustyTeal.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const Gap(4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x20000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Sora',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
