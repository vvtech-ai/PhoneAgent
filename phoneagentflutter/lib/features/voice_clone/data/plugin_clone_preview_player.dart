import '../../../core/diagnostics/clone_diagnostics.dart';
import '../../../core/diagnostics/diagnostic_event.dart';
import 'clone_preview_diagnostics.dart';
import 'clone_preview_audio_session.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import '../domain/clone_preview_player.dart';
import 'clone_preview_source.dart'
    if (dart.library.io) 'clone_preview_source_io.dart';

class PluginClonePreviewPlayer implements ClonePreviewPlayer {
  PluginClonePreviewPlayer({
    AudioPlayer Function()? create,
    CloneDiagnostics? diagnostics,
    Future<void> Function()? prepareSession,
  }) : _create = create ?? AudioPlayer.new,
       _prepareSession = prepareSession ?? prepareClonePreviewAudioSession,
       _diagnostics = ClonePreviewDiagnostics(diagnostics);
  final AudioPlayer Function() _create;
  final Future<void> Function() _prepareSession;
  final ClonePreviewDiagnostics _diagnostics;
  _Playback? _active;
  bool _closed = false;

  @override
  Future<void> play(Uint8List wav) async {
    if (_closed ||
        _active != null ||
        wav.isEmpty ||
        wav.length > 10 * 1024 * 1024) {
      throw StateError('Preview unavailable');
    }
    _diagnostics.input(wav);
    final run = _Playback(_create, _diagnostics, _prepareSession);
    _active = run;
    try {
      await run.start(wav);
    } finally {
      if (identical(_active, run) && run.audioStopped) _active = null;
    }
  }

  @override
  Future<void> stop() async {
    final run = _active;
    if (run != null) await _diagnostics.run(ClonePreviewStage.stop, run.stop);
    if (identical(_active, run)) _active = null;
  }

  @override
  Future<void> close() async {
    _closed = true;
    await stop();
  }
}

class _Playback {
  _Playback(this.create, this.diagnostics, this.prepareSession);
  final Future<void> Function() prepareSession;
  final ClonePreviewDiagnostics diagnostics;
  final AudioPlayer Function() create;
  AudioPlayer? _player;
  bool audioStopped = false;
  final _done = Completer<void>(), _finished = Completer<void>();
  bool _stopped = false, _failed = false;
  Future<void> start(Uint8List bytes) async {
    AudioPlayer? player;
    ClonePreviewSource? source;
    StreamSubscription<AudioEvent>? events;
    try {
      await diagnostics.run(ClonePreviewStage.prepare, prepareSession);
      if (_stopped) return;
      AudioLogger.logLevel = AudioLogLevel.none;
      player = _player = create();
      events = player.eventStream.listen(
        (event) {
          if (event.eventType == AudioEventType.complete &&
              !_done.isCompleted) {
            _done.complete();
          }
        },
        onError: (Object error) {
          diagnostics.failed(ClonePreviewStage.event, error);
          _failed = true;
          if (!_done.isCompleted) _done.complete();
        },
      );
      final preparedSource = await diagnostics.run(
        ClonePreviewStage.source,
        () => ClonePreviewSource.create(bytes),
      );
      source = preparedSource;
      if (_stopped) return;
      final activePlayer = player;
      await diagnostics.run(
        ClonePreviewStage.prepare,
        () => activePlayer.play(
          preparedSource.source,
          ctx: AudioContext(
            iOS: AudioContextIOS(
              category: AVAudioSessionCategory.playback,
            ),
          ),
        ),
      );
      if (!_stopped) {
        await diagnostics.run(ClonePreviewStage.playback, () async {
          await _done.future.timeout(const Duration(minutes: 5));
          if (_failed) throw StateError('Preview failed');
        });
      }
      if (_failed) throw StateError('Preview failed');
    } finally {
      try {
        await diagnostics.run(ClonePreviewStage.dispose, () async {
          await player?.dispose();
        });
        audioStopped = true;
      } finally {
        try {
          await events?.cancel();
        } finally {
          try {
            await diagnostics.run(ClonePreviewStage.sourceCleanup, () async {
              await source?.close();
            });
          } finally {
            if (!_finished.isCompleted) _finished.complete();
          }
        }
      }
    }
  }

  Future<void> stop() async {
    _stopped = true;
    if (!_done.isCompleted) _done.complete();
    await _finished.future;
    if (!audioStopped) {
      await _player?.dispose();
      audioStopped = true;
    }
  }
}
