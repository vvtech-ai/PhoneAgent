import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/voice/capture_turn_gate.dart';
import 'package:phone_agent/features/conversation/domain/voice/voice_gateway_event.dart';

void main() {
  const partial = VoiceTranscript('测试片段', isFinal: false);
  const finalText = VoiceTranscript('测试终稿', isFinal: true);
  late CaptureTurnGate gate;
  setUp(() => gate = CaptureTurnGate());

  test('PCM and transcripts wait for ready', () {
    expect(gate.phase, CapturePhase.idle);
    final turn = gate.begin();
    expect(gate.allowsPcm(turn), isFalse);
    expect(gate.accept(turn, partial), isFalse);
    expect(gate.accept(turn, finalText), isFalse);
    expect(gate.ready(turn), isTrue);
    expect(gate.ready(turn), isFalse);
    expect(gate.allowsPcm(turn), isTrue);
  });

  test('Release before ready never starts a microphone later', () {
    final turn = gate.begin();
    expect(gate.release(turn), isFalse);
    expect(gate.ready(turn), isFalse);
    expect(gate.allowsPcm(turn), isFalse);
    expect(gate.accept(turn, finalText), isFalse);
    expect(gate.phase, CapturePhase.ended);
  });

  test('Active ASR segments do not imply release or one final per press', () {
    final turn = gate.begin();
    gate.ready(turn);
    expect(gate.accept(turn, partial), isTrue);
    expect(gate.accept(turn, finalText), isTrue);
    expect(gate.accept(turn, finalText), isTrue);
    expect(gate.allowsPcm(turn), isTrue);
  });

  test('Release stops PCM and partial but admits exactly one late final', () {
    final turn = gate.begin();
    gate.ready(turn);
    expect(gate.release(turn), isTrue);
    expect(gate.release(turn), isFalse);
    expect(gate.allowsPcm(turn), isFalse);
    expect(gate.accept(turn, partial), isFalse);
    expect(
      gate.accept(turn, const VoiceTranscript(' ', isFinal: true)),
      isFalse,
    );
    expect(gate.accept(turn, finalText), isTrue);
    expect(gate.accept(turn, finalText), isFalse);
    expect(gate.release(turn), isFalse);
    expect(gate.accept(turn, finalText), isFalse);
  });

  test('Cancel rejects late results at each live phase', () {
    for (final phase in [
      CapturePhase.awaitingReady,
      CapturePhase.capturing,
      CapturePhase.awaitingFinal,
    ]) {
      final turn = gate.begin();
      if (phase != CapturePhase.awaitingReady) gate.ready(turn);
      if (phase == CapturePhase.awaitingFinal) gate.release(turn);
      expect(gate.cancel(turn), isTrue);
      expect(gate.cancel(turn), isFalse);
      expect(gate.ready(turn), isFalse);
      expect(gate.accept(turn, finalText), isFalse);
      expect(gate.allowsPcm(turn), isFalse);
    }
  });

  test('Old callbacks cannot affect a new turn', () {
    final old = gate.begin();
    gate.ready(old);
    gate.release(old);
    final next = gate.begin();
    expect(next.generation, greaterThan(old.generation));
    expect(gate.ready(old), isFalse);
    expect(gate.accept(old, finalText), isFalse);
    expect(gate.cancel(old), isFalse);
    expect(gate.expire(old), isFalse);
    expect(gate.release(old), isFalse);
    expect(gate.phase, CapturePhase.awaitingReady);
    expect(gate.ready(next), isTrue);
  });

  test('Same generation from another gate does not confer ownership', () {
    final own = gate.begin();
    final foreign = CaptureTurnGate().begin();
    expect(own.generation, foreign.generation);
    expect(gate.ready(foreign), isFalse);
    expect(gate.cancel(foreign), isFalse);
    expect(gate.ready(own), isTrue);
  });

  test('Lifecycle expiry ends late-final admission without a timer here', () {
    final turn = gate.begin();
    expect(gate.expire(turn), isFalse);
    gate.ready(turn);
    gate.release(turn);
    expect(gate.expire(turn), isTrue);
    expect(gate.expire(turn), isFalse);
    expect(gate.accept(turn, finalText), isFalse);
  });
}
