import '../../../../core/diagnostics/translation_recording_diagnostics.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/recording_audio.dart';

enum RecordingAudioPhase {
  idle,
  loading,
  processing,
  ready,
  playing,
  paused,
  failed,
}

class RecordingAudioState {
  const RecordingAudioState({
    this.phase = RecordingAudioPhase.idle,
    this.busy = false,
    this.saving = false,
    this.retrying = false,
    this.positionMillis = 0,
    this.durationMillis = 0,
    this.message = '',
    this.waveform,
  });
  final RecordingAudioPhase phase;
  final bool busy, saving, retrying;
  final int positionMillis, durationMillis;
  final String message;
  final List<double>? waveform;
  String get remaining {
    final seconds =
        ((durationMillis - positionMillis).clamp(0, durationMillis) / 1000)
            .ceil();
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}

class RecordingAudioController extends StateNotifier<RecordingAudioState> {
  RecordingAudioController({
    required this.repository,
    this.diagnostics = const TranslationRecordingDiagnostics(null),
    required this.player,
    required this.exporter,
    required this.isCurrent,
    this.loadOnAction = false,
    this.refreshAfterCompletion = false,
    int logicalDurationMillis = 0,
  }) : super(
         RecordingAudioState(
           durationMillis: logicalDurationMillis < 0
               ? 0
               : logicalDurationMillis,
         ),
       ) {
    _events = player.events.listen(_event, onError: (Object _) => _fail());
  }
  final TranslationRecordingDiagnostics diagnostics;
  final RecordingAudioRepository repository;
  final RecordingAudioPlayer player;
  final RecordingAudioExporter exporter;
  final bool Function() isCurrent;

  /// Ordinary receipts fetch media only after an explicit action. Translation
  /// history keeps its existing preload + explicit playback behavior.
  final bool loadOnAction;
  final bool refreshAfterCompletion;
  late final StreamSubscription<RecordingPlaybackEvent> _events;
  RecordingAudioAsset? _asset;
  int _generation = 0;
  int _saveGeneration = 0;
  bool _closed = false;
  bool get _current => mounted && !_closed && isCurrent();
  bool _same(int generation) => _current && _generation == generation;

  Future<void> load({bool retry = false}) async {
    if (!_current || state.busy || state.saving || (!retry && _asset != null)) {
      return;
    }
    final generation = ++_generation;
    _asset = null;
    _set(
      phase: RecordingAudioPhase.loading,
      retrying: retry && state.phase == RecordingAudioPhase.failed,
      busy: true,
      message: '',
      position: 0,
    );
    try {
      await player.stop();
      if (!_same(generation)) return;
      final asset = await repository.load(
        retry: retry,
        processing: () {
          if (_same(generation)) _set(phase: RecordingAudioPhase.processing);
        },
      );
      if (!_same(generation)) return;
      final duration = await diagnostics.run(
        'recordingPrepare',
        () => player.prepare(asset),
      );
      if (!_same(generation)) return;
      _asset = asset;
      _set(
        phase: RecordingAudioPhase.ready,
        busy: false,
        duration: duration,
        position: 0,
        message: '',
      );
    } catch (_) {
      if (_same(generation)) _fail();
    }
  }

  Future<void> primary() async {
    if (!_current || state.busy || state.saving) return;
    if (loadOnAction && _asset == null) {
      final loading = load(retry: state.phase == RecordingAudioPhase.failed);
      final generation = _generation;
      await loading;
      if (!_same(generation) || _asset == null) return;
    }
    if (state.phase == RecordingAudioPhase.failed) {
      await load(retry: true);
      return;
    }
    if (_asset == null) return;
    final generation = _generation;
    final phase = state.phase;
    _set(busy: true, message: '');
    try {
      if (phase == RecordingAudioPhase.playing) {
        _set(phase: RecordingAudioPhase.paused);
        await player.pause();
      } else if (phase == RecordingAudioPhase.paused ||
          phase == RecordingAudioPhase.ready) {
        _set(phase: RecordingAudioPhase.playing);
        if (phase == RecordingAudioPhase.paused) {
          await player.resume();
        } else {
          await player.play();
        }
      }
      // Completion/interruption may arrive before the platform future resolves.
      // Never overwrite its authoritative phase with our previous intent.
      if (_same(generation)) _set(busy: false);
    } catch (_) {
      if (_same(generation)) _fail();
    }
  }

  Future<void> save() async {
    if (!_current || state.saving) return;
    if (loadOnAction && !state.busy && _asset == null) {
      final loading = load(retry: state.phase == RecordingAudioPhase.failed);
      final generation = _generation;
      await loading;
      if (!_same(generation) || _asset == null) return;
    }
    if (state.phase == RecordingAudioPhase.loading ||
        state.phase == RecordingAudioPhase.processing) {
      _set(message: '录音正在加载，请稍后再下载');
      return;
    }
    if (state.busy) return;
    final asset = _asset;
    if (asset == null || state.phase == RecordingAudioPhase.failed) {
      _set(message: '录音文件加载失败，请重新加载后再下载');
      return;
    }
    final generation = ++_saveGeneration;
    bool currentSave() => _current && _saveGeneration == generation;
    _set(saving: true, message: '');
    try {
      final saved = await exporter.save(asset);
      if (currentSave()) _set(saving: false, message: saved ? '录音已保存' : '');
    } catch (_) {
      if (currentSave()) {
        ++_generation;
        _asset = null;
        _set(
          phase: RecordingAudioPhase.failed,
          busy: false,
          saving: false,
          message: '录音保存失败，请重新加载后再下载',
        );
        try {
          await player.stop();
        } catch (_) {
          /* Already failed; no raw exception. */
        }
      }
    }
  }

  void _event(RecordingPlaybackEvent event) {
    if (!_current || _asset == null) return;
    if (event.failed) {
      _fail();
      return;
    }
    _set(
      position: event.positionMillis,
      duration: event.durationMillis,
      waveform: event.waveform,
    );
    if (event.completed) {
      if (refreshAfterCompletion) {
        unawaited(interruptPlayback().catchError((Object _) {}));
        return;
      }
      _set(phase: RecordingAudioPhase.ready, busy: false, position: 0);
    } else if (event.paused && state.phase == RecordingAudioPhase.playing) {
      _set(phase: RecordingAudioPhase.paused);
    }
  }

  /// Metadata does not replace the actual duration of a prepared player.
  void updateLogicalDuration(int? durationMillis) {
    if (_current && _asset == null && durationMillis != null) {
      _set(duration: durationMillis);
    }
  }

  /// Invalidates in-flight load/play work, but not an independent local export.
  Future<void> interruptPlayback() async {
    if (_closed) return;
    final generation = ++_generation;
    _asset = null;
    _set(busy: true, position: 0, message: '');
    try {
      await player.stop();
      if (_same(generation)) {
        _set(phase: RecordingAudioPhase.idle, busy: false);
      }
    } catch (_) {
      if (_same(generation)) {
        _set(
          phase: RecordingAudioPhase.failed,
          busy: false,
          message: '音频停止失败，请重试',
        );
      }
      rethrow; // The arbiter must not hand off a failed native release.
    }
  }

  void _fail() {
    if (!_current) return;
    ++_generation;
    ++_saveGeneration;
    _asset = null;
    _set(
      phase: RecordingAudioPhase.failed,
      busy: false,
      saving: false,
      message: '音频加载失败',
    );
    unawaited(player.stop().catchError((Object _) {}));
  }

  void _set({
    RecordingAudioPhase? phase,
    bool? busy,
    bool? saving,
    bool? retrying,
    int? position,
    int? duration,
    String? message,
    List<double>? waveform,
  }) {
    if (!_current) return;
    final total = duration != null && duration > 0
        ? duration
        : state.durationMillis;
    state = RecordingAudioState(
      phase: phase ?? state.phase,
      busy: busy ?? state.busy,
      saving: saving ?? state.saving,
      retrying:
          retrying ??
          (phase != null && phase != RecordingAudioPhase.loading
              ? false
              : state.retrying),
      positionMillis: (position ?? state.positionMillis).clamp(0, total),
      durationMillis: total,
      message: message ?? state.message,
      waveform: (phase != null && phase != RecordingAudioPhase.playing)
          ? null
          : waveform ?? state.waveform,
    );
  }

  @override
  void dispose() {
    _closed = true;
    ++_generation;
    repository.close();
    unawaited(_events.cancel());
    unawaited(player.close().catchError((Object _) {}));
    unawaited(exporter.close().catchError((Object _) {}));
    super.dispose();
  }
}
