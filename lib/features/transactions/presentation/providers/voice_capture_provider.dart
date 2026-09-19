import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

import 'package:expense_manager/core/services/analytics_service.dart';
import 'package:expense_manager/core/services/voice_input_gateway.dart';
import 'package:expense_manager/features/transactions/data/voice_transaction_parser.dart';
import 'package:expense_manager/features/transactions/domain/parsed_voice_transaction.dart';

enum VoiceCaptureStatus { idle, recording, processing }

/// Owns the single [VoiceInputGateway] recorder shared by every voice entry
/// point (the in-screen mic button and the home-widget quick-capture
/// overlay) and enforces that only one of them can be recording/processing
/// at a time — there is only one microphone.
///
/// This is the single place that does permission-check → start → stop →
/// read → validate → parse → cleanup, so a fix here reaches every caller
/// instead of needing to be repeated per widget. Callers own their own
/// max-duration [Timer] (using [maxDuration]) and call [stopAndProcess]
/// when it fires, so that widget can update its own UI when the auto-stop
/// happens — this class only guarantees that at most one of them is ever
/// actually recording.
class VoiceCaptureNotifier extends Notifier<VoiceCaptureStatus> {
  /// Recordings are capped so an absent-minded "hold" doesn't record (and
  /// upload) minutes of audio.
  static const maxDuration = Duration(seconds: 20);

  /// How long a recording can go without any sample above
  /// [_silenceThresholdDb] before [start]'s `onSilenceTimeout` fires — covers
  /// both "never started talking" and "trailed off mid-sentence".
  static const silenceTimeout = Duration(seconds: 2);

  /// dBFS below which an amplitude sample counts as silence. Ambient phone-mic
  /// room noise typically sits well below this while normal speech sits
  /// above it, but device mic sensitivity varies — tune on real hardware if
  /// this proves too eager/lax.
  static const _silenceThresholdDb = -35.0;

  static const _amplitudeSampleInterval = Duration(milliseconds: 200);

  /// A WAV header alone is 44 bytes — this just filters an accidental
  /// instant tap, not short-but-real speech.
  static const _minBytes = 4000;

  StreamSubscription<Amplitude>? _amplitudeSub;
  Timer? _silenceTimer;

  @override
  VoiceCaptureStatus build() => VoiceCaptureStatus.idle;

  VoiceInputGateway get _gateway => ref.read(voiceInputGatewayProvider);

  /// Starts recording. Returns `false` (no-op) when a capture is already in
  /// progress, the mic permission is denied, or the recorder itself fails
  /// to start — callers should treat that the same as "unavailable".
  ///
  /// When [onSilenceTimeout] is given, it's called once — from a caller
  /// perspective, exactly like the [maxDuration] timer the caller already
  /// owns — after [silenceTimeout] passes without any sample above
  /// [_silenceThresholdDb]. It's the caller's job to react (typically by
  /// calling [stopAndProcess]), same as with the max-duration timer.
  Future<bool> start({void Function()? onSilenceTimeout}) async {
    if (state != VoiceCaptureStatus.idle) return false;
    // Set eagerly (before any await) so a second, near-simultaneous call
    // sees a non-idle state immediately instead of racing this one.
    state = VoiceCaptureStatus.recording;

    if (!await _gateway.hasPermission()) {
      state = VoiceCaptureStatus.idle;
      return false;
    }
    try {
      await _gateway.start();
    } catch (_) {
      state = VoiceCaptureStatus.idle;
      return false;
    }

    if (onSilenceTimeout != null) _startSilenceMonitoring(onSilenceTimeout);

    AnalyticsService.track(AnalyticsService.voiceUsed);
    return true;
  }

  void _startSilenceMonitoring(void Function() onSilenceTimeout) {
    _resetSilenceTimer(onSilenceTimeout);
    _amplitudeSub = _gateway
        .onAmplitudeChanged(_amplitudeSampleInterval)
        .listen((amplitude) {
      if (amplitude.current > _silenceThresholdDb) {
        _resetSilenceTimer(onSilenceTimeout);
      }
    });
  }

  void _resetSilenceTimer(void Function() onSilenceTimeout) {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(silenceTimeout, () {
      _stopSilenceMonitoring();
      onSilenceTimeout();
    });
  }

  void _stopSilenceMonitoring() {
    _amplitudeSub?.cancel();
    _amplitudeSub = null;
    _silenceTimer?.cancel();
    _silenceTimer = null;
  }

  /// Stops the current recording and parses it. Returns `null` when nothing
  /// was recording (no-op), the recorder captured nothing, the clip is too
  /// short, or the AI didn't recognize a transaction. Throws an `AppFailure`
  /// subtype (see `core/errors/failures.dart`) on network/rate-limit/server
  /// errors — callers should catch that separately from a generic error.
  Future<ParsedVoiceTransaction?> stopAndProcess({
    List<Map<String, String>> subcategories = const [],
  }) async {
    if (state != VoiceCaptureStatus.recording) return null;
    _stopSilenceMonitoring();
    // Flip immediately so a concurrent call (double-tap racing the timer)
    // sees "processing" and no-ops instead of stopping/parsing twice.
    state = VoiceCaptureStatus.processing;

    try {
      final path = await _gateway.stop();
      if (path == null) return null;

      final file = File(path);
      try {
        final bytes = await file.readAsBytes();
        if (bytes.length < _minBytes) return null;
        return await ref.read(voiceTransactionParserProvider).parse(
              bytes,
              mimeType: _gateway.mimeType,
              subcategories: subcategories,
            );
      } finally {
        try {
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
    } finally {
      state = VoiceCaptureStatus.idle;
    }
  }

  /// Cancels an in-progress recording. Safe to call unconditionally from a
  /// widget's `dispose()`: it's a no-op unless a recording — necessarily
  /// this widget's own, since only one can be active at a time — is still
  /// running (a capture already handed off to `processing` is left alone).
  void cancelIfRecording() {
    if (state != VoiceCaptureStatus.recording) return;
    _stopSilenceMonitoring();
    _gateway.cancel();
    state = VoiceCaptureStatus.idle;
  }
}

final voiceCaptureProvider =
    NotifierProvider<VoiceCaptureNotifier, VoiceCaptureStatus>(
  VoiceCaptureNotifier.new,
);
