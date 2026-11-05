import 'dart:async';
import 'dart:typed_data';
import 'package:phone_agent/features/calls/domain/call_monitor_media.dart';
import 'package:phone_agent/features/calls/domain/call_session.dart';

CallMonitorTicket monitorTicket({
  int rate = 16000,
  int channels = 1,
  String encoding = 'PCM_S16LE',
  DateTime? expires,
}) => CallMonitorTicket(
  ticket: 'synthetic+/=?',
  expiresAt: expires ?? DateTime.now().add(const Duration(minutes: 1)),
  sampleRate: rate,
  channels: channels,
  encoding: encoding,
);

class TestMonitorOutput implements CallMonitorOutput {
  final played = <Uint8List>[];
  final gates = <Completer<void>>[];
  int starts = 0, stops = 0, mutes = 0;
  bool stopped = false,
      enabled = true,
      failStop = false,
      failRoute = false,
      bluetooth = true;
  String selected = 'earpiece';
  @override
  Future<void> start(int sampleRateHz) async {
    starts++;
  }

  @override
  Future<void> play(Uint8List bytes) {
    played.add(bytes);
    final done = Completer<void>();
    gates.add(done);
    return done.future;
  }

  void flush() {
    for (final gate in gates) {
      if (!gate.isCompleted) {
        gate.completeError(const CallMonitorFailure('flushed'));
      }
    }
    gates.clear();
  }

  @override
  Future<void> setPlaybackEnabled(bool value) async {
    mutes++;
    flush();
    enabled = value;
  }

  @override
  Future<CallMonitorRoute> route({String? select}) async {
    if (failRoute) throw const CallMonitorFailure('route');
    if (select != null) selected = select;
    if (selected == 'bluetooth' && !bluetooth) selected = 'earpiece';
    return CallMonitorRoute(selected: selected, bluetooth: bluetooth);
  }

  @override
  Future<void> stop() async {
    stops++;
    if (failStop) throw const CallMonitorFailure('release');
    stopped = true;
    flush();
  }
}

class TestMonitorMedia implements CallMonitorMedia {
  final events = StreamController<void>(
    sync: true,
    onCancel: () => Future<void>.microtask(() {}),
  );
  int starts = 0, closes = 0, controls = 0;
  bool failStart = false, failClose = false, failRoute = false;
  bool enabled = true, bluetooth = true;
  String selected = 'earpiece';
  Completer<void>? startGate, controlGate;
  Completer<CallMonitorRoute>? routeGate;
  @override
  Stream<void> get disconnected => events.stream;
  @override
  Future<void> start(CallMonitorTicket ticket, String initialRoute) async {
    starts++;
    await startGate?.future;
    if (failStart) throw const CallMonitorFailure('start');
  }

  @override
  Future<void> setPlaybackEnabled(bool value) async {
    controls++;
    await controlGate?.future;
    enabled = value;
  }

  @override
  Future<CallMonitorRoute> route({String? select}) async {
    if (select == null && routeGate != null) return routeGate!.future;
    if (failRoute) throw const CallMonitorFailure('route');
    selected = select ?? selected;
    if (!bluetooth && selected == 'bluetooth') selected = 'earpiece';
    return CallMonitorRoute(selected: selected, bluetooth: bluetooth);
  }

  @override
  Future<void> close() async {
    closes++;
    if (failClose) throw const CallMonitorFailure('release');
  }
}
