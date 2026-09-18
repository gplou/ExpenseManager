import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Thin abstraction over `package:record` so widgets that drive the
/// microphone can be tested without the platform plugin.
///
/// Records raw audio (never transcribes on-device) — the file is sent to
/// [VoiceTransactionParser], which hands it to Gemini for both the
/// transcription and the transaction field extraction.
abstract interface class VoiceInputGateway {
  /// The MIME type of the file [stop] resolves to — sent alongside the
  /// audio bytes so the caller never has to know the concrete encoder.
  String get mimeType;

  /// Checks (and, unless already decided, requests) the microphone
  /// permission.
  Future<bool> hasPermission();

  /// Starts recording to a fresh temporary file.
  Future<void> start();

  /// Stops recording and returns the recorded file path, or `null` if
  /// nothing was captured.
  Future<String?> stop();

  /// Stops and discards the current recording (e.g. on dispose).
  Future<void> cancel();
}

class AudioRecorderGateway implements VoiceInputGateway {
  AudioRecorderGateway() : _recorder = AudioRecorder();
  final AudioRecorder _recorder;

  /// WAV needs no container/codec negotiation with Gemini (unlike e.g.
  /// `record`'s AAC-LC, which writes an MPEG-4/m4a container that would
  /// need relabeling), at the cost of a larger upload than a compressed
  /// codec would produce. 16kHz mono keeps that cost down.
  @override
  final String mimeType = 'audio/wav';

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start() async {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_capture_${clock.now().microsecondsSinceEpoch}.wav';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    // The platform recorder can silently fail to actually start (e.g. an
    // AudioRecord init failure) while still resolving this call normally —
    // isRecording() is the one reliable way to catch that immediately
    // instead of only noticing 20s later from an unusably short file.
    if (!await _recorder.isRecording()) {
      throw StateError('Recorder failed to start');
    }
  }

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> cancel() => _recorder.cancel();
}

final voiceInputGatewayProvider = Provider<VoiceInputGateway>((ref) {
  final gateway = AudioRecorderGateway();
  ref.onDispose(() => gateway._recorder.dispose());
  return gateway;
});
