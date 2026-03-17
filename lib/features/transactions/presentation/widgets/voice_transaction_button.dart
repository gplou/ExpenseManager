import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../../core/config/router.dart';
import '../../data/voice_transaction_parser.dart';
import '../../domain/parsed_voice_transaction.dart';

enum _VoiceState { idle, listening, processing }

class VoiceTransactionButton extends ConsumerStatefulWidget {
  const VoiceTransactionButton({super.key});

  @override
  ConsumerState<VoiceTransactionButton> createState() =>
      _VoiceTransactionButtonState();
}

class _VoiceTransactionButtonState extends ConsumerState<VoiceTransactionButton>
    with SingleTickerProviderStateMixin {
  final _speech = SpeechToText();
  final _parser = VoiceTransactionParser();
  _VoiceState _state = _VoiceState.idle;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _onTap() async {
    if (_state == _VoiceState.listening) {
      await _speech.stop();
      return;
    }
    if (_state != _VoiceState.idle) return;

    final available = await _speech.initialize(
      onError: (_) {
        if (mounted) setState(() => _state = _VoiceState.idle);
      },
    );

    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Micrófono no disponible')),
        );
      }
      return;
    }

    setState(() => _state = _VoiceState.listening);

    await _speech.listen(
      localeId: 'es_ES',
      onResult: (result) {
        if (result.finalResult) {
          _processText(result.recognizedWords);
        }
      },
    );
  }

  Future<void> _processText(String text) async {
    if (text.trim().isEmpty) {
      setState(() => _state = _VoiceState.idle);
      return;
    }

    setState(() => _state = _VoiceState.processing);

    ParsedVoiceTransaction? parsed;
    try {
      parsed = await _parser.parse(text);
    } catch (e) {
      if (!mounted) return;
      setState(() => _state = _VoiceState.idle);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _state = _VoiceState.idle);

    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo interpretar. Inténtalo de nuevo.'),
        ),
      );
      return;
    }

    context.push(AppRoutes.addTransaction, extra: parsed);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_state) {
      _VoiceState.processing => const FloatingActionButton(
          heroTag: 'voiceFab',
          onPressed: null,
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white,
            ),
          ),
        ),
      _VoiceState.listening => ScaleTransition(
          scale: _pulseAnim,
          child: FloatingActionButton(
            heroTag: 'voiceFab',
            onPressed: _onTap,
            backgroundColor: Colors.red,
            child: const Icon(Icons.stop_rounded),
          ),
        ),
      _VoiceState.idle => FloatingActionButton(
          heroTag: 'voiceFab',
          onPressed: _onTap,
          child: const Icon(Icons.mic_outlined),
        ),
    };
  }
}
