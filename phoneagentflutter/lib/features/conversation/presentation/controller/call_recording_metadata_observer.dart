import 'dart:async';
import '../../domain/call_recording.dart';

/// Visibility owns metadata polling; leaving a lazy-list item does not imply
/// stopping host-owned playback. Failed refreshes retain the last metadata.
class CallRecordingMetadataObserver {
  CallRecordingMetadataObserver({
    required this.repository,
    required this.onMetadata,
    required this.isCurrent,
  });
  final CallRecordingRepository repository;
  final void Function(CallRecordingInfo) onMetadata;
  final bool Function() isCurrent;
  Timer? _poll, _deadline;
  int _generation = 0;
  int _failures = 0;
  bool _active = false, _closed = false;

  void start() {
    if (_closed || _active || !isCurrent()) return;
    _active = true;
    _failures = 0;
    final generation = ++_generation;
    _deadline = Timer(const Duration(seconds: 60), stop);
    unawaited(_read(generation));
  }

  bool _same(int generation) =>
      !_closed && _active && _generation == generation && isCurrent();

  Future<void> _read(int generation) async {
    if (!_same(generation)) return;
    try {
      final info = await repository.metadata();
      if (!_same(generation)) return;
      _failures = 0;
      onMetadata(info);
      if (!_same(generation)) return;
      if (info.processing) {
        _poll = Timer(const Duration(seconds: 2), () => _read(generation));
      } else {
        stop();
      }
    } catch (_) {
      if (!_same(generation)) return;
      ++_failures;
      final delaySeconds = _failures == 1
          ? 2
          : _failures == 2
          ? 4
          : 8;
      _poll = Timer(Duration(seconds: delaySeconds), () => _read(generation));
      // The original deadline stops retries; a failed read keeps visible data.
    }
  }

  void stop() {
    ++_generation;
    _active = false;
    _failures = 0;
    _poll?.cancel();
    _deadline?.cancel();
    _poll = null;
    _deadline = null;
  }

  void close() {
    _closed = true;
    stop();
  }
}
