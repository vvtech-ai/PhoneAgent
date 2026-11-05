import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/preview_call_repository.dart';
import '../../domain/call_session.dart';
import 'call_presentation.dart';
import 'call_session_controller.dart';
import 'call_session_state.dart';

enum CallPreviewScenario {
  dialing,
  connected,
  bluetooth,
  pollingError,
  hangupError,
  awaitingOutcome,
}

class CallPreviewState {
  const CallPreviewState({
    required this.call,
    required this.monitor,
    this.seconds = 0,
  });
  final CallSessionState call;
  final CallMonitorView monitor;
  final int seconds;
}

/// Owns only synthetic ports; the call lifecycle is the production controller.
class CallPreviewController extends StateNotifier<CallPreviewState> {
  CallPreviewController(
    CallPreviewScenario scenario, {
    this.mediaDelay = const Duration(milliseconds: 350),
  }) : repository = PreviewCallRepository(),
       super(
         CallPreviewState(
           call: CallSessionState(
             target: CallSessionTarget(taskId: 'mock-conversation'),
           ),
           monitor: CallMonitorView(
             bluetoothAvailable: scenario == CallPreviewScenario.bluetooth,
           ),
         ),
       ) {
    if (scenario != CallPreviewScenario.dialing) repository.connected();
    if (scenario == CallPreviewScenario.connected ||
        scenario == CallPreviewScenario.bluetooth) {
      repository.append();
    }
    repository.failPoll = scenario == CallPreviewScenario.pollingError;
    repository.failHangup = scenario == CallPreviewScenario.hangupError;
    if (scenario == CallPreviewScenario.awaitingOutcome) repository.end();
    call = CallSessionController(
      conversationId: 'mock-conversation',
      target: CallSessionTarget(taskId: 'mock-conversation'),
      repository: repository,
    );
    _removeListener = call.addListener((value) {
      if (!mounted) return;
      final active = CallPresentation.active(value);
      if (!active) _mediaGeneration++;
      state = CallPreviewState(
        call: value,
        seconds: state.seconds,
        monitor: active
            ? state.monitor
            : CallMonitorView(
                bluetoothAvailable: state.monitor.bluetoothAvailable,
              ),
      );
    });
    call.start();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted &&
          CallPresentation.active(state.call) &&
          state.call.snapshot?.normalizedState == 'CONNECTED') {
        state = CallPreviewState(
          call: state.call,
          monitor: state.monitor,
          seconds: state.seconds + 1,
        );
      }
    });
  }
  final PreviewCallRepository repository;
  final Duration mediaDelay;
  late final CallSessionController call;
  late final void Function() _removeListener;
  Timer? _clock;
  int _mediaGeneration = 0;
  bool failNextMonitor = false;
  CallPreviewState get snapshot => state;

  void _monitor(CallMonitorPhase phase, {CallAudioSource? source}) {
    if (!mounted) return;
    state = CallPreviewState(
      call: state.call,
      seconds: state.seconds,
      monitor: CallMonitorView(
        phase: phase,
        source: source ?? state.monitor.source,
        bluetoothAvailable: state.monitor.bluetoothAvailable,
      ),
    );
  }

  Future<void> toggleMonitor() async {
    if (!mounted ||
        !CallPresentation.active(state.call) ||
        state.monitor.busy) {
      return;
    }
    if (state.monitor.playing) {
      _mediaGeneration++;
      _monitor(CallMonitorPhase.muted);
      return;
    }
    if (state.monitor.phase == CallMonitorPhase.muted) {
      _monitor(CallMonitorPhase.playing);
      return;
    }
    await _connect(CallMonitorPhase.connecting);
  }

  Future<void> reconnect() async {
    if (!mounted || !state.monitor.playing) return;
    await _connect(CallMonitorPhase.reconnecting);
  }

  Future<void> _connect(CallMonitorPhase phase) async {
    final generation = ++_mediaGeneration;
    final fail = failNextMonitor;
    failNextMonitor = false;
    _monitor(phase);
    await Future<void>.delayed(mediaDelay);
    if (!mounted ||
        generation != _mediaGeneration ||
        !CallPresentation.active(state.call)) {
      return;
    }
    _monitor(fail ? CallMonitorPhase.failed : CallMonitorPhase.playing);
  }

  void source(CallAudioSource source) {
    if (mounted &&
        state.monitor.playing &&
        state.monitor.sources.contains(source)) {
      _monitor(CallMonitorPhase.playing, source: source);
    }
  }

  Future<void> connected() async {
    repository.connected();
    await call.refresh();
  }

  Future<void> transcript() async {
    repository.append();
    await call.refresh();
  }

  Future<void> remoteEnd() async {
    repository.end();
    await call.refresh();
  }

  Future<void> recoverPolling() async {
    repository.failPoll = false;
    await call.refresh();
  }

  void outcome() => call.markAgentOutcomeReceived('mock-call');
  Future<bool> hangUp() => call.hangUp();
  @override
  void dispose() {
    _mediaGeneration++;
    _clock?.cancel();
    _removeListener();
    call.dispose();
    super.dispose();
  }
}
