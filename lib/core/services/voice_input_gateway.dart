import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Thin abstraction over `package:speech_to_text` so widgets that drive
/// the microphone can be tested without the platform plugin.
///
/// Only the subset actually used by the app is exposed (initialize, listen
/// with a locale + result callback, stop). Keep it small.
abstract interface class VoiceInputGateway {
  Future<bool> initialize({SpeechErrorListener? onError});

  Future<void> listen({
    required String localeId,
    required SpeechResultListener onResult,
  });

  Future<void> stop();

  /// Maps an app locale code (es/en/fr/de) to the speech_to_text locale id
  /// it expects. Shared by every voice-capture entry point (quick-capture
  /// widget and the in-screen mic button).
  static String localeIdFor(String langCode) => switch (langCode) {
        'es' => 'es_ES',
        'en' => 'en_US',
        'fr' => 'fr_FR',
        'de' => 'de_DE',
        _ => 'en_US',
      };
}

class SpeechToTextGateway implements VoiceInputGateway {
  SpeechToTextGateway() : _speech = SpeechToText();
  final SpeechToText _speech;

  @override
  Future<bool> initialize({SpeechErrorListener? onError}) {
    return _speech.initialize(onError: onError);
  }

  @override
  Future<void> listen({
    required String localeId,
    required SpeechResultListener onResult,
  }) {
    return _speech.listen(localeId: localeId, onResult: onResult);
  }

  @override
  Future<void> stop() => _speech.stop();
}

final voiceInputGatewayProvider = Provider<VoiceInputGateway>((ref) {
  return SpeechToTextGateway();
});
