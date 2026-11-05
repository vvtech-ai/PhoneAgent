import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/audio/diagnosed_pcm_output.dart';
import 'package:phone_agent/core/audio/pcm_output.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/diagnostics/media_diagnostics.dart';

class _Output implements PcmOutput {
  _Output(this.error);
  final Object error;
  @override
  Future<void> start(int rate) async => throw error;
  @override
  Future<void> play(Uint8List bytes) async => throw error;
  @override
  Future<void> stop() async => throw error;
}

void main() {
  for (final pair in {
    'output_busy': DiagnosticMediaReason.deviceBusy,
    'output_capacity': DiagnosticMediaReason.deviceCapacity,
    'output_start_failed': DiagnosticMediaReason.deviceStartFailed,
    'output_play_failed': DiagnosticMediaReason.devicePlayFailed,
    'output_interrupted': DiagnosticMediaReason.interrupted,
    'output_stalled': DiagnosticMediaReason.deviceStalled,
    'output_focus_lost': DiagnosticMediaReason.deviceFocusLost,
    'output_unavailable': DiagnosticMediaReason.deviceUnavailable,
    'private synthetic exception': DiagnosticMediaReason.deviceFailure,
  }.entries) {
    test('preserves safe PCM reason for ${pair.key}', () async {
      final events = <DiagnosticEvent>[];
      final output = DiagnosedPcmOutput(
        _Output(PcmOutputFailure(pair.key)),
        MediaDiagnostics(events.add, DiagnosticMediaComponent.pcmOutput),
      );
      await expectLater(output.start(24000), throwsA(isA<PcmOutputFailure>()));
      await expectLater(
        output.play(Uint8List(2)),
        throwsA(isA<PcmOutputFailure>()),
      );
      for (final event in events.where(
        (e) => e.result == DiagnosticResult.failed,
      )) {
        expect(event.media!.reason, pair.value);
        expect(
          DiagnosticMediaDetails.fromJson(event.media!.toJson()).reason,
          pair.value,
        );
        expect(
          event.media!.toJson().values,
          isNot(contains('private synthetic exception')),
        );
      }
    });
  }
  test('normal cancellation remains cancellation', () async {
    final events = <DiagnosticEvent>[];
    final output = DiagnosedPcmOutput(
      _Output(const PcmOutputFailure('output_cancelled')),
      MediaDiagnostics(events.add, DiagnosticMediaComponent.pcmOutput),
    );
    await expectLater(output.start(24000), throwsA(isA<PcmOutputFailure>()));
    expect(events.last.result, DiagnosticResult.cancelled);
    expect(events.last.media!.reason, isNull);
  });
}
