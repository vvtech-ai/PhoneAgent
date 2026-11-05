import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/audio/playback_ledger.dart';

void main() {
  late PlaybackLedger ledger;
  setUp(() => ledger = PlaybackLedger(capacityBytes: 640));

  test('Complete waits for actual consumption of all accepted chunks', () {
    final turn = ledger.begin();
    final first = ledger.enqueue(turn, 200).chunk!;
    final second = ledger.enqueue(turn, 300).chunk!;
    expect(ledger.queuedBytes, 500);
    expect(ledger.complete(turn), isTrue);
    expect(ledger.phase, PlaybackPhase.draining);
    expect(ledger.enqueue(turn, 20).status, EnqueueStatus.inactive);
    expect(ledger.consumed(turn, first), isTrue);
    expect(ledger.phase, PlaybackPhase.draining);
    expect(ledger.consumed(turn, second), isTrue);
    expect(ledger.phase, PlaybackPhase.drained);
    expect(ledger.queuedBytes, 0);
  });

  test('Temporary underrun is not end of playback input', () {
    final turn = ledger.begin();
    final chunk = ledger.enqueue(turn, 200).chunk!;
    ledger.consumed(turn, chunk);
    expect(ledger.phase, PlaybackPhase.accepting);
    expect(ledger.enqueue(turn, 100).status, EnqueueStatus.accepted);
  });

  test(
    'Backpressure keeps counts unchanged and permits retry after playback',
    () {
      final turn = ledger.begin();
      final first = ledger.enqueue(turn, 500).chunk!;
      final blocked = ledger.enqueue(turn, 200);
      expect(blocked.status, EnqueueStatus.backpressure);
      expect(blocked.chunk, isNull);
      expect(ledger.queuedBytes, 500);
      expect(ledger.availableBytes, 140);
      ledger.consumed(turn, first);
      expect(ledger.enqueue(turn, 200).status, EnqueueStatus.accepted);
    },
  );

  test('Duplicate consumption and complete are idempotent', () {
    final turn = ledger.begin();
    final first = ledger.enqueue(turn, 640).chunk!;
    expect(ledger.consumed(turn, first), isTrue);
    expect(ledger.consumed(turn, first), isFalse);
    expect(ledger.queuedBytes, 0);
    expect(ledger.complete(turn), isTrue);
    expect(ledger.complete(turn), isFalse);
    expect(ledger.phase, PlaybackPhase.drained);
  });

  test('Cancel clears queued work and rejects late audio and callbacks', () {
    final turn = ledger.begin();
    final oldChunk = ledger.enqueue(turn, 200).chunk!;
    ledger.complete(turn);
    expect(ledger.cancel(turn), isTrue);
    expect(ledger.cancel(turn), isFalse);
    expect(ledger.phase, PlaybackPhase.cancelled);
    expect(ledger.queuedBytes, 0);
    expect(ledger.enqueue(turn, 200).status, EnqueueStatus.inactive);
    expect(ledger.consumed(turn, oldChunk), isFalse);
    expect(ledger.complete(turn), isFalse);
  });

  test(
    'Old generation cannot enqueue complete consume or cancel a new turn',
    () {
      final old = ledger.begin();
      final oldChunk = ledger.enqueue(old, 200).chunk!;
      ledger.cancel(old);
      final next = ledger.begin();
      final nextChunk = ledger.enqueue(next, 100).chunk!;
      expect(next.generation, greaterThan(old.generation));
      expect(ledger.enqueue(old, 20).status, EnqueueStatus.inactive);
      expect(ledger.complete(old), isFalse);
      expect(ledger.cancel(old), isFalse);
      expect(ledger.consumed(old, nextChunk), isFalse);
      expect(ledger.consumed(next, oldChunk), isFalse);
      expect(ledger.queuedBytes, 100);
    },
  );

  test(
    'Foreign turn and receipt with same numeric generation are rejected',
    () {
      final own = ledger.begin();
      final other = PlaybackLedger(capacityBytes: 640);
      final foreign = other.begin();
      final foreignChunk = other.enqueue(foreign, 20).chunk!;
      expect(own.generation, foreign.generation);
      expect(ledger.enqueue(foreign, 20).status, EnqueueStatus.inactive);
      expect(ledger.complete(foreign), isFalse);
      expect(ledger.consumed(own, foreignChunk), isFalse);
    },
  );

  test('Cannot replace a live player without explicit cancel', () {
    final turn = ledger.begin();
    expect(ledger.begin, throwsStateError);
    ledger.enqueue(turn, 100);
    ledger.complete(turn);
    expect(ledger.begin, throwsStateError);
    ledger.cancel(turn);
    expect(ledger.begin, returnsNormally);
  });

  test('Reject invalid capacity and chunks that cannot ever fit', () {
    expect(() => PlaybackLedger(capacityBytes: 0), throwsArgumentError);
    expect(() => PlaybackLedger(capacityBytes: -1), throwsArgumentError);
    final turn = ledger.begin();
    for (final bytes in [-1, 0, 641]) {
      expect(() => ledger.enqueue(turn, bytes), throwsArgumentError);
    }
    expect(ledger.queuedBytes, 0);
  });
}
