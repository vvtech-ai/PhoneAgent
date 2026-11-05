import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

/// Continuous model chunks with native write backpressure, never a UI frame timer.
class DomesticLocalPlayout {
  DomesticLocalPlayout({
    required this.write,
    required this.onFailure,
    this.onStatistics,
  });
  final Future<void> Function(Uint8List) write;
  final void Function(Object) onFailure;
  final void Function(Map<String, int>)? onStatistics;
  final _chunks = Queue<Uint8List>();
  bool _closed = false, _pumping = false;
  int _bytes = 0, _maxBytes = 0, _clips = 0, _samples = 0;
  final _cancelled = Completer<void>();
  void enqueue(Uint8List pcm) {
    if (_closed) return;
    if (pcm.length.isOdd || _bytes + pcm.length > 960000) {
      onFailure(StateError('Local playback capacity'));
      return;
    }
    final data = ByteData.sublistView(pcm);
    for (var i = 0; i < pcm.length; i += 2) {
      final sample = data.getInt16(i, Endian.little);
      if (sample == -32768 || sample == 32767) _clips++;
      _samples++;
    }
    _chunks.add(Uint8List.fromList(pcm));
    _bytes += pcm.length;
    if (_bytes > _maxBytes) _maxBytes = _bytes;
    if (!_pumping) unawaited(_pump());
  }

  Future<void> _pump() async {
    _pumping = true;
    try {
      while (!_closed && _chunks.isNotEmpty) {
        final pcm = _chunks.removeFirst();
        for (var offset = 0; offset < pcm.length && !_closed; offset += 6400) {
          final end = (offset + 6400).clamp(0, pcm.length);
          await Future.any<void>([
            write(Uint8List.sublistView(pcm, offset, end)),
            _cancelled.future,
          ]);
          if (_closed) return;
          _bytes -= end - offset;
        }
      }
    } catch (error) {
      if (!_closed) onFailure(error);
    } finally {
      _pumping = false;
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _cancelled.complete();
    _chunks.clear();
    try {
      onStatistics?.call({
        'localMaxQueuedBytes': _maxBytes,
        'localSamples': _samples,
        'localClippedSamples': _clips,
      });
    } catch (_) {
      /* isolated */
    }
  }
}
