import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/diagnostics/diagnostic_event.dart';
import '../../../../core/diagnostics/diagnostic_journal.dart';
import '../../../../core/diagnostics/media_diagnostics.dart';
import '../../domain/call_monitor_media.dart';
import '../../domain/call_session.dart';
import 'call_presentation.dart';

/// One visible single call; no call creation, hangup, microphone or UI navigation.
class CallMonitorController extends StateNotifier<CallMonitorView> {
  CallMonitorController({
    required this.loadTicket,
    required this.createMedia,
    required this.isCurrent,
    this.diagnostics,
    this.supported = true,
    this.reconnectDelay = const Duration(milliseconds: 800),
    this.routeInterval = const Duration(seconds: 1),
    this.ticketTimeout = const Duration(seconds: 8),
    this.firstAudioTimeout = const Duration(seconds: 10),
  }) : super(const CallMonitorView());
  final Future<CallMonitorTicket> Function(CallSessionTarget) loadTicket;
  final CallMonitorMedia Function() createMedia;
  final bool Function() isCurrent;
  final MediaDiagnostics? diagnostics;
  final Duration reconnectDelay,
      routeInterval,
      ticketTimeout,
      firstAudioTimeout;
  final bool supported;
  CallSessionTarget? _target;
  CallMonitorMedia? _media;
  StreamSubscription<void>? _events;
  Timer? _retry, _routes;
  Future<bool>? _cleanup;
  int _generation = 0, _attempts = 0, _routeVersion = 0;
  bool _active = false, _control = false, _readingRoute = false;
  bool _connected = true;
  Completer<bool>? _connectedWait;
  CallMonitorView get snapshot => state;
  bool _valid(int generation) =>
      mounted && _active && isCurrent() && generation == _generation;

  void bind(
    CallSessionTarget? target, {
    required bool active,
    bool connected = true,
  }) {
    final valid = active && target != null && target.callId.isNotEmpty;
    final changed =
        _target?.callId != target?.callId || _target?.taskId != target?.taskId;
    if (changed || !valid && _active) unawaited(stop());
    _target = target;
    _active = valid;
    _connected = connected;
    if (valid && connected && _connectedWait?.isCompleted == false) {
      _connectedWait!.complete(true);
      _connectedWait = null;
    }
  }

  Future<void> toggle() async {
    if (!mounted || !_active || !isCurrent() || state.busy || _control) return;
    if (!supported) {
      _view(CallMonitorPhase.failed, error: 'Web仅支持隔离演练，实际监听请使用手机');
      return;
    }
    if (state.phase == CallMonitorPhase.playing ||
        state.phase == CallMonitorPhase.muted) {
      final enabled = state.phase == CallMonitorPhase.muted;
      await _command(
        () => _media!.setPlaybackEnabled(enabled),
        phase: enabled ? CallMonitorPhase.playing : CallMonitorPhase.muted,
      );
    } else {
      _attempts = 0;
      await _connect(++_generation, CallMonitorPhase.connecting);
    }
  }

  void _view(
    CallMonitorPhase phase, {
    CallMonitorRoute? route,
    String error = '',
  }) {
    if (!mounted) return;
    final changed =
        state.phase != phase ||
        route != null && state.source.name != route.selected;
    state = CallMonitorView(
      phase: phase,
      source: route == null
          ? state.source
          : CallAudioSource.values.firstWhere(
              (s) => s.name == route.selected,
              orElse: () => state.source,
            ),
      bluetoothAvailable: route?.bluetooth ?? state.bluetoothAvailable,
      error: error,
      controlsBusy: _control,
    );
    if (changed) _trace(phase.name);
  }

  void _trace(String phase) {
    assert(() {
      final level = switch (phase) {
        'failed' => DiagnosticLogLevel.error,
        'reconnecting' => DiagnosticLogLevel.warn,
        'playing' || 'muted' => DiagnosticLogLevel.info,
        _ => DiagnosticLogLevel.debug,
      };
      if (level.index < configuredDiagnosticLogLevel.index) return true;
      String safe(String? value) {
        final text = (value ?? '').replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
        return text.substring(0, text.length.clamp(0, 128));
      }

      debugPrint(
        'CALL_MONITOR_STATE taskId=${safe(_target?.taskId)} callId=${safe(_target?.callId)} phase=$phase attempt=$_attempts',
      );
      return true;
    }());
  }

  Future<void> _connect(int generation, CallMonitorPhase phase) async {
    if (!_valid(generation)) return;
    _view(phase);
    if (!await _drop()) {
      if (_valid(generation)) {
        _view(CallMonitorPhase.failed, error: '监听播放释放失败，请重试');
      }
      return;
    }
    if (!_valid(generation)) return;
    var awaitingAudio = false;
    try {
      if (!_connected) {
        _connectedWait = Completer<bool>();
        final connected = await _connectedWait!.future;
        if (!connected || !_valid(generation)) return;
      }
      final ticket = await loadTicket(_target!).timeout(ticketTimeout);
      if (!_valid(generation)) return;
      final media = createMedia();
      _media = media;
      _events = media.disconnected.listen(
        (_) => unawaited(_lost(generation)),
        onError: (Object _) => unawaited(_outputFailed(generation)),
      );
      await media.start(ticket, state.source.name).timeout(ticketTimeout);
      if (!_valid(generation)) return;
      if (media is CallMonitorAudioReadiness) {
        awaitingAudio = true;
        final ready = await (media as CallMonitorAudioReadiness).audioStarted
            .timeout(firstAudioTimeout);
        if (!_valid(generation)) return;
        if (!ready) throw const CallMonitorFailure('no_pcm');
      }
      final route = await media.route(select: state.source.name);
      if (!_valid(generation)) return;
      _attempts = 0;
      _view(CallMonitorPhase.playing, route: route);
      _routes = Timer.periodic(routeInterval, (_) => unawaited(refreshRoute()));
    } catch (error) {
      if (_valid(generation)) {
        diagnostics?.record(
          DiagnosticMediaStage.protocol,
          DiagnosticResult.failed,
          reason: error is TimeoutException
              ? (awaitingAudio
                    ? DiagnosticMediaReason.firstAudioTimeout
                    : DiagnosticMediaReason.readyTimeout)
              : DiagnosticMediaReason.connectFailed,
        );
      }
      if (_valid(generation)) await _lost(generation);
    }
  }

  Future<void> _outputFailed(int generation) async {
    if (!_valid(generation)) return;
    final expected = generation + 1;
    await stop();
    if (_valid(expected)) {
      _view(CallMonitorPhase.failed, error: '监听播放已中断，可重新开启');
    }
  }

  Future<void> _lost(int generation) async {
    if (!_valid(generation)) return;
    final next = ++_generation;
    _routes?.cancel();
    _retry?.cancel();
    _control = false;
    _view(CallMonitorPhase.reconnecting);
    if (!await _drop()) {
      if (_valid(next)) _view(CallMonitorPhase.failed, error: '监听播放释放失败，请重试');
      return;
    }
    if (!_valid(next)) return;
    if (_attempts >= 3) {
      _view(CallMonitorPhase.failed);
      return;
    }
    _attempts++;
    _retry = Timer(
      reconnectDelay,
      () => unawaited(_connect(next, CallMonitorPhase.reconnecting)),
    );
  }

  Future<void> select(CallAudioSource source) async {
    if (!_valid(_generation) ||
        !supported ||
        _control ||
        !state.sources.contains(source)) {
      return;
    }
    if (!{
      CallMonitorPhase.playing,
      CallMonitorPhase.muted,
    }.contains(state.phase)) {
      _view(
        state.phase,
        route: CallMonitorRoute(
          selected: source.name,
          bluetooth: state.bluetoothAvailable,
        ),
      );
      return;
    }
    await _command(() async {
      final route = await _media!.route(select: source.name);
      return route;
    });
  }

  Future<void> refreshRoute() async {
    if (!mounted ||
        _control ||
        _readingRoute ||
        !{
          CallMonitorPhase.playing,
          CallMonitorPhase.muted,
        }.contains(state.phase)) {
      return;
    }
    if (!isCurrent()) {
      await stop();
      return;
    }
    final generation = _generation;
    final version = _routeVersion;
    _readingRoute = true;
    try {
      final route = await _media!.route();
      if (_valid(generation) && !_control && version == _routeVersion) {
        _view(state.phase, route: route);
      }
    } catch (_) {
      if (_valid(generation)) await stop();
    } finally {
      _readingRoute = false;
    }
  }

  Future<void> _command(
    Future<Object?> Function() command, {
    CallMonitorPhase? phase,
  }) async {
    if (_control || !_valid(_generation) || _media == null) return;
    final generation = _generation;
    _routeVersion++;
    _control = true;
    _view(state.phase);
    try {
      final result = await command();
      if (!_valid(generation)) return;
      _control = false;
      _view(
        phase ?? state.phase,
        route: result is CallMonitorRoute ? result : null,
      );
    } catch (_) {
      if (!_valid(generation)) return;
      _control = false;
      // A route rejection does not close a working stream. Failed mute must
      // stop output rather than falsely claiming local silence.
      if (phase != null) {
        await stop();
      } else {
        _view(state.phase, error: '音源切换未成功，请重试');
      }
    }
  }

  Future<bool> _drop() => _cleanup ??= _release();
  Future<bool> _release() async {
    final media = _media;
    try {
      await _events?.cancel();
      _events = null;
      await media?.close();
      if (identical(media, _media)) _media = null;
      return true;
    } catch (_) {
      return false;
    } finally {
      _cleanup = null;
    }
  }

  Future<void> stop() async {
    ++_generation;
    if (_connectedWait?.isCompleted == false) _connectedWait!.complete(false);
    _connectedWait = null;
    _retry?.cancel();
    _routes?.cancel();
    _control = false;
    if (mounted) state = const CallMonitorView();
    _trace('off');
    final generation = _generation;
    if (!await _drop() && mounted && generation == _generation) {
      _view(CallMonitorPhase.failed, error: '监听播放释放失败，请重试');
    }
  }

  @override
  void dispose() {
    _active = false;
    unawaited(stop());
    super.dispose();
  }
}
