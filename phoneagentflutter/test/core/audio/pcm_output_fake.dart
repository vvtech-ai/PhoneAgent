import 'dart:async';
import 'dart:typed_data';
import 'package:phone_agent/core/audio/pcm_output.dart';

class PcmOutputFake implements PcmOutput {
  Completer<void>? startGate, stopGate;
  bool failStart = false, failStop = false;
  int starts = 0, stops = 0;
  final chunks = <Uint8List>[];
  final pending = <Completer<void>>[];
  @override
  Future<void> start(int sampleRateHz) async {
    starts++;
    await startGate?.future;
    if (failStart) throw StateError('private native detail');
  }

  @override
  Future<void> play(Uint8List bytes) {
    chunks.add(bytes);
    final gate = Completer<void>();
    pending.add(gate);
    return gate.future;
  }

  void consume() {
    final items = List.of(pending);
    pending.clear();
    for (final item in items) {
      item.complete();
    }
  }

  void fail() {
    final items = List.of(pending);
    pending.clear();
    for (final item in items) {
      item.completeError(StateError('private'));
    }
  }

  @override
  Future<void> stop() async {
    stops++;
    await stopGate?.future;
    if (failStop) throw StateError('private stop detail');
    fail();
  }
}
