import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/audio/audio_resource_coordinator.dart';

void main() {
  test('Only one owner can hold audio, including same-owner reacquisition', () {
    final coordinator = AudioResourceCoordinator();
    final first = coordinator.acquire('asr')!;
    expect(coordinator.owns(first), isTrue);
    expect(coordinator.acquire('tts'), isNull);
    expect(coordinator.acquire('asr'), isNull);
    expect(coordinator.active, same(first));
  });

  test('Stale release cannot free the next owner', () {
    final coordinator = AudioResourceCoordinator();
    final first = coordinator.acquire('asr')!;
    expect(coordinator.release(first), isTrue);
    expect(coordinator.release(first), isFalse);
    final next = coordinator.acquire('tts')!;
    expect(next.generation, greaterThan(first.generation));
    expect(coordinator.release(first), isFalse);
    expect(coordinator.active, same(next));
    expect(coordinator.release(next), isTrue);
    expect(coordinator.active, isNull);
  });

  test('Foreign token and empty owner cannot acquire authority', () {
    final coordinator = AudioResourceCoordinator();
    final own = coordinator.acquire('asr')!;
    final foreign = AudioResourceCoordinator().acquire('asr')!;
    expect(own.generation, foreign.generation);
    expect(coordinator.release(foreign), isFalse);
    expect(coordinator.owns(own), isTrue);
    expect(() => coordinator.acquire(' '), throwsArgumentError);
  });
}
