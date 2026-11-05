import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/audio/audio_playback_focus.dart';
import '../../conversation/data/voice/voice_socket.dart';
import '../domain/call_monitor_media.dart';
import '../domain/call_session.dart';
import '../presentation/controller/call_monitor_controller.dart';
import 'call_monitor_stream.dart';
import 'focused_call_monitor_media.dart';

/// Only ticket, wire and device are synthetic. Protocol/lifecycle are shared.
class PreviewCallMonitor extends ChangeNotifier {
  final focus = AudioPlaybackFocus();
  PreviewMonitorSocket? socket;
  PreviewMonitorOutput? output;
  int tickets = 0, receivedBytes = 0;
  bool failConnections = false, bluetooth = true, _closed = false;
  void changed() {
    if (!_closed) notifyListeners();
  }

  CallMonitorController create() {
    late final CallMonitorController controller;
    controller = CallMonitorController(
      isCurrent: () => !_closed,
      loadTicket: (_) async {
        tickets++;
        changed();
        if (failConnections) throw const CallMonitorFailure('synthetic');
        return CallMonitorTicket(
          ticket: 'synthetic',
          expiresAt: DateTime.now().add(const Duration(minutes: 1)),
          sampleRate: 16000,
          channels: 1,
          encoding: 'PCM_S16LE',
        );
      },
      createMedia: () => FocusedCallMonitorMedia(
        focus: focus,
        isCurrent: () => !_closed,
        onInterrupted: () => unawaited(controller.stop()),
        delegate: CallMonitorStream(
          apiBase: Uri.parse('https://synthetic.invalid/api/'),
          connect: (_) async => socket = PreviewMonitorSocket(),
          output: output = PreviewMonitorOutput(this),
        ),
      ),
    );
    return controller;
  }

  void pcm() => socket?.add(Uint8List(3200));
  void disconnect() => socket?.fail();
  void toggleFailure() {
    failConnections = !failConnections;
    changed();
  }

  void toggleBluetooth() {
    bluetooth = !bluetooth;
    changed();
  }

  @override
  void dispose() {
    _closed = true;
    unawaited(focus.stopAll().catchError((Object _) {}));
    super.dispose();
  }
}

class PreviewMonitorSocket implements VoiceSocket {
  final _messages = StreamController<Object>(
    sync: true,
    onCancel: () => Future<void>.microtask(() {}),
  );
  bool closed = false;
  @override
  Stream<Object> get messages => _messages.stream;
  void add(Object value) {
    if (!closed) _messages.add(value);
  }

  void fail() {
    if (!closed) _messages.addError(const CallMonitorFailure('synthetic'));
  }

  @override
  void send(Object message) => throw StateError('Monitor must never send');
  @override
  Future<void> close() {
    closed = true;
    unawaited(_messages.close());
    return Future<void>.microtask(() {});
  }
}

class PreviewMonitorOutput implements CallMonitorOutput {
  PreviewMonitorOutput(this.owner);
  final PreviewCallMonitor owner;
  String selected = 'earpiece';
  bool enabled = true, stopped = false;
  void _check() {
    if (stopped) throw const CallMonitorFailure('stopped');
  }

  @override
  Future<void> start(int sampleRateHz) async {
    _check();
  }

  @override
  Future<void> play(Uint8List bytes) async {
    _check();
    if (!enabled) throw const CallMonitorFailure('muted');
    owner.receivedBytes += bytes.length;
    owner.changed();
  }

  @override
  Future<void> setPlaybackEnabled(bool value) async {
    _check();
    enabled = value;
  }

  @override
  Future<CallMonitorRoute> route({String? select}) async {
    _check();
    if (select == 'bluetooth' && !owner.bluetooth) {
      throw const CallMonitorFailure('route_unavailable');
    }
    selected = select ?? selected;
    if (selected == 'bluetooth' && !owner.bluetooth) selected = 'earpiece';
    return CallMonitorRoute(selected: selected, bluetooth: owner.bluetooth);
  }

  @override
  Future<void> stop() async {
    stopped = true;
  }
}
