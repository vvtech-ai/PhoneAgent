import 'dart:async';
import 'package:flutter/services.dart';
import '../../translation_history/domain/recording_audio.dart';
import '../domain/recording_waveform_policy.dart';

/// One native player per receipt; the existing arbiter owns playback admission.
class DeviceCallRecordingPlayer implements RecordingAudioPlayer {
  DeviceCallRecordingPlayer({
    MethodChannel? channel,
    Stream<dynamic>? nativeEvents,
  }) : _channel =
           channel ?? const MethodChannel('phone_agent/call_recording_player'),
       _source = nativeEvents;
  static int _nextId = 0;
  static final _nativeEvents = const EventChannel(
    'phone_agent/call_recording_player/events',
  ).receiveBroadcastStream();
  final String _id = 'recording-${++_nextId}';
  final MethodChannel _channel;
  final _events = StreamController<RecordingPlaybackEvent>.broadcast();
  final _wave = RecordingWaveformPolicy();
  final Stream<dynamic>? _source;
  StreamSubscription<dynamic>? _subscription;
  Future<void> _tail = Future.value();
  int _generation = 0;
  bool _closed = false, _playing = false;
  @override
  Stream<RecordingPlaybackEvent> get events => _events.stream;

  Future<T?> _command<T>(
    String method, [
    Map<String, Object?> extra = const {},
  ]) {
    final args = <String, Object?>{
      'playerId': _id,
      'generation': _generation,
      ...extra,
    };
    final result = _tail.then((_) => _channel.invokeMethod<T>(method, args));
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  void _accept(dynamic event) {
    if (_closed ||
        event is! Map ||
        event['playerId'] != _id ||
        event['generation'] != _generation) {
      return;
    }
    final type = event['type'];
    List<double>? waveform;
    if (type == 'waveform') {
      if (!_playing) return;
      if (event['bytes'] case final List values) {
        waveform = _wave.bytes(values.cast<int>(), rms: event['rms'] as int?);
      } else if (event['levels'] case final List values) {
        waveform = _wave.levels(
          values.map((v) => (v as num).toDouble()).toList(),
        );
      } else {
        waveform = _wave.reset();
      }
    }
    final terminal =
        type == 'completed' || type == 'failed' || type == 'paused';
    if (terminal) {
      _playing = false;
      waveform = _wave.reset();
    }
    _events.add(
      RecordingPlaybackEvent(
        positionMillis: event['positionMillis'] as int?,
        durationMillis: event['durationMillis'] as int?,
        completed: type == 'completed',
        failed: type == 'failed',
        paused: type == 'paused',
        waveform: waveform,
      ),
    );
  }

  @override
  Future<int?> prepare(RecordingAudioAsset asset) async {
    if (_closed) throw StateError('Recording player closed');
    _subscription ??= (_source ?? _nativeEvents).listen(
      _accept,
      onError: (Object _) {
        /* Meter availability cannot fail playback. */
      },
    );
    _generation++;
    _playing = false;
    _wave.reset();
    return _command<int>('prepare', {
      'source': asset.remoteUri?.toString() ?? asset.localPath,
      'remote': asset.remoteUri != null,
    });
  }

  @override
  Future<void> play() async {
    if (_closed) return;
    _playing = true;
    await _command<void>('play');
  }

  @override
  Future<void> resume() async {
    if (_closed) return;
    _playing = true;
    await _command<void>('resume');
  }

  @override
  Future<void> pause() async {
    _playing = false;
    _events.add(RecordingPlaybackEvent(waveform: _wave.reset()));
    await _command<void>('pause');
  }

  @override
  Future<void> stop() async {
    _playing = false;
    ++_generation;
    if (!_closed) _events.add(RecordingPlaybackEvent(waveform: _wave.reset()));
    await _command<void>('stop');
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _playing = false;
    ++_generation;
    final subscription = _subscription;
    if (subscription == null) {
      await _events.close();
      return;
    }
    await subscription.cancel();
    try {
      await _command<void>('stop');
    } finally {
      await _events.close();
    }
  }
}
