import 'dart:typed_data';
import '../diagnostics/diagnostic_event.dart';
import '../diagnostics/media_diagnostics.dart';
import 'pcm_output.dart';

/// Only successful native play completion counts; queued bytes are not playback.
class DiagnosedPcmOutput implements PcmOutput {
  DiagnosedPcmOutput(this.delegate, this.diagnostics);
  final PcmOutput delegate;
  final MediaDiagnostics diagnostics;
  bool _first = true, _playFailed = false;
  @override
  Future<void> start(int sampleRateHz) async {
    final watch = Stopwatch()..start();
    diagnostics.record(DiagnosticMediaStage.start, DiagnosticResult.started);
    try {
      await delegate.start(sampleRateHz);
      diagnostics.record(
        DiagnosticMediaStage.start,
        DiagnosticResult.succeeded,
        elapsedMs: watch.elapsedMilliseconds,
      );
    } catch (error) {
      _failure(DiagnosticMediaStage.start, error, watch.elapsedMilliseconds);
      rethrow;
    }
  }

  @override
  Future<void> play(Uint8List bytes) async {
    final watch = _first ? (Stopwatch()..start()) : null;
    try {
      await delegate.play(bytes);
      if (_first && bytes.isNotEmpty) {
        _first = false;
        diagnostics.record(
          DiagnosticMediaStage.play,
          DiagnosticResult.succeeded,
          elapsedMs: watch?.elapsedMilliseconds ?? 0,
          audioBytes: bytes.length,
        );
      }
    } catch (error) {
      if (!_playFailed) {
        _playFailed = true;
        _failure(
          DiagnosticMediaStage.play,
          error,
          watch?.elapsedMilliseconds ?? 0,
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    final watch = Stopwatch()..start();
    diagnostics.record(DiagnosticMediaStage.stop, DiagnosticResult.started);
    try {
      await delegate.stop();
      diagnostics.record(
        DiagnosticMediaStage.stop,
        DiagnosticResult.succeeded,
        elapsedMs: watch.elapsedMilliseconds,
      );
    } catch (error) {
      _failure(DiagnosticMediaStage.stop, error, watch.elapsedMilliseconds);
      rethrow;
    }
  }

  void _failure(
    DiagnosticMediaStage stage,
    Object error, [
    int elapsedMs = 0,
  ]) => diagnostics.record(
    stage,
    error is PcmOutputFailure && error.code == 'output_cancelled'
        ? DiagnosticResult.cancelled
        : DiagnosticResult.failed,
    elapsedMs: elapsedMs,
    native: error is PcmOutputFailure ? error.native : null,
    reason: error is PcmOutputFailure && error.code == 'output_cancelled'
        ? null
        : switch (error is PcmOutputFailure ? error.code : '') {
            'output_busy' => DiagnosticMediaReason.deviceBusy,
            'output_capacity' => DiagnosticMediaReason.deviceCapacity,
            'output_start_failed' => DiagnosticMediaReason.deviceStartFailed,
            'output_play_failed' => DiagnosticMediaReason.devicePlayFailed,
            'output_stop_failed' => DiagnosticMediaReason.deviceStopFailed,
            'output_unavailable' => DiagnosticMediaReason.deviceUnavailable,
            'output_stalled' => DiagnosticMediaReason.deviceStalled,
            'output_focus_lost' => DiagnosticMediaReason.deviceFocusLost,
            'output_interrupted' => DiagnosticMediaReason.interrupted,
            _ => DiagnosticMediaReason.deviceFailure,
          },
  );
}
