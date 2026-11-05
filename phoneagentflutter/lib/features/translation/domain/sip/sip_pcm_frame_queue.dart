import 'dart:collection';
import 'dart:typed_data';
import 'sip_lease.dart';

/// Native 16k mono framing: 20ms frames, 160ms prebuffer, 30s hard bound.
/// A completed short response drains its padded tail instead of waiting forever.
class SipPcmFrameQueue {
  SipPcmFrameQueue({this.maxBytes = 960000, this.prebufferBytes = 5120});
  final int maxBytes, prebufferBytes;
  final _chunks = Queue<Uint8List>();
  int _offset = 0, _bytes = 0;
  bool _buffering = true, _started = false, _done = false;
  int get queuedBytes => _bytes;
  bool get hasAudio => _bytes > 0;
  bool get canDrain => _bytes >= 640 || (_done && _bytes > 0);

  void enqueue(Uint8List pcm16k) {
    if (pcm16k.isEmpty || pcm16k.length.isOdd) {
      throw const SipLeaseFailure('INVALID_PCM');
    }
    if (_bytes + pcm16k.length > maxBytes) {
      throw const SipLeaseFailure('MEDIA_AUDIO_OVERFLOW');
    }
    _done = false;
    _chunks.add(Uint8List.fromList(pcm16k));
    _bytes += pcm16k.length;
  }

  void markDone() => _done = true;

  Uint8List? nextFrame() {
    if (_buffering && _bytes < prebufferBytes && !_done) {
      return _started ? Uint8List(640) : null;
    }
    if (_bytes == 0) {
      _buffering = true;
      return _started ? Uint8List(640) : null;
    }
    if (_bytes < 640 && !_done) {
      _buffering = true;
      return _started ? Uint8List(640) : null;
    }
    _buffering = false;
    _started = true;
    final frame = Uint8List(640);
    var position = 0;
    while (position < frame.length && _chunks.isNotEmpty) {
      final chunk = _chunks.first;
      final count = (chunk.length - _offset).clamp(0, frame.length - position);
      frame.setRange(position, position + count, chunk, _offset);
      position += count;
      _offset += count;
      _bytes -= count;
      if (_offset == chunk.length) {
        _chunks.removeFirst();
        _offset = 0;
      }
    }
    return frame;
  }

  void clear() {
    _chunks.clear();
    _offset = _bytes = 0;
    _buffering = true;
    _started = _done = false;
  }
}
