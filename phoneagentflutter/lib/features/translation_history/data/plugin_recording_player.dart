import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import '../domain/recording_audio.dart';

/// Shared local-file or validated token-URL player. No auto-start on prepare.
class PluginRecordingPlayer implements RecordingAudioPlayer {
  PluginRecordingPlayer({AudioPlayer Function()? create})
    : _create = create ?? AudioPlayer.new;
  final AudioPlayer Function() _create;
  final _events = StreamController<RecordingPlaybackEvent>.broadcast();
  final _subscriptions = <StreamSubscription<dynamic>>[];
  AudioPlayer? _player;
  Future<void> _tail = Future<void>.value();
  bool _closed = false;

  @override
  Stream<RecordingPlaybackEvent> get events => _events.stream;

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  void _emit(RecordingPlaybackEvent event) {
    if (!_closed) _events.add(event);
  }

  @override
  Future<int?> prepare(RecordingAudioAsset asset) => _serial(() async {
    if (_closed) throw StateError('Recording player closed');
    await _release();
    if (_closed) throw StateError('Recording player closed');
    // Plugin errors can contain private paths or signed token URLs.
    // UI/controller expose a sanitized failure instead.
    AudioLogger.logLevel = AudioLogLevel.none;
    final player = _player = _create();
    void failed(Object _) => _emit(const RecordingPlaybackEvent(failed: true));
    _subscriptions.addAll([
      player.onPositionChanged.listen(
        (value) =>
            _emit(RecordingPlaybackEvent(positionMillis: value.inMilliseconds)),
        onError: failed,
      ),
      player.onDurationChanged.listen(
        (value) =>
            _emit(RecordingPlaybackEvent(durationMillis: value.inMilliseconds)),
        onError: failed,
      ),
      player.onPlayerComplete.listen(
        (_) => _emit(const RecordingPlaybackEvent(completed: true)),
        onError: failed,
      ),
      player.onPlayerStateChanged.listen((value) {
        if (value == PlayerState.paused) {
          _emit(const RecordingPlaybackEvent(paused: true));
        }
      }, onError: failed),
    ]);
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setSource(
      asset.remoteUri != null
          ? UrlSource(asset.remoteUri.toString(), mimeType: asset.contentType)
          : DeviceFileSource(asset.localPath, mimeType: asset.contentType),
    );
    if (_closed) throw StateError('Recording player closed');
    return (await player.getDuration())?.inMilliseconds;
  });

  Future<void> _command(Future<void> Function(AudioPlayer) command) =>
      _serial(() async {
        if (_closed) return;
        final player = _player;
        if (player == null) throw StateError('Recording not prepared');
        await command(player);
      });

  @override
  Future<void> play() => _command((player) async {
    await player.seek(Duration.zero);
    if (!_closed) await player.resume();
  });
  @override
  Future<void> resume() => _command((player) => player.resume());
  @override
  Future<void> pause() => _command((player) => player.pause());
  @override
  Future<void> stop() => _serial(() async {
    if (!_closed) await _release();
  });

  Future<void> _release() async {
    final player = _player;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    if (player != null) await player.dispose();
    if (identical(_player, player)) _player = null;
  }

  @override
  Future<void> close() {
    _closed = true;
    return _serial(() async {
      await _release();
      if (!_events.isClosed) await _events.close();
    });
  }
}
