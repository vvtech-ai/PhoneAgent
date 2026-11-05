import 'dart:collection';
import 'dart:typed_data';
import 'sip_rtp_packet.dart';

/// Worker-owned packet jitter guard. All audio and telephone events share order.
class RtpPlayoutQueue {
  RtpPlayoutQueue({required this.audioPayloadType, required this.silenceByte});
  final int audioPayloadType, silenceByte;
  final _queue = Queue<SipRtpPacket>();
  SipRtpPacket? _last;
  int _sequenceOffset = 0, _timeOffset = 0, _bufferSince = 0;
  bool _buffering = true;
  int sent = 0, fillers = 0, underflows = 0, maxQueued = 0;
  int get length => _queue.length;
  bool enqueue(SipRtpPacket packet) {
    if (_queue.length >= 100) return false; // Two seconds, including DTMF.
    _queue.add(packet);
    if (_queue.length > maxQueued) maxQueued = _queue.length;
    return true;
  }

  SipRtpPacket? next(int nowMs) {
    if (_buffering) {
      if (_bufferSince == 0) _bufferSince = nowMs + 1;
      if (_queue.length < 3 && nowMs + 1 - _bufferSince < 60) return _filler();
      if (_queue.isEmpty) return _filler();
      _buffering = false;
    }
    if (_queue.isEmpty) {
      _buffering = true;
      _bufferSince = nowMs + 1;
      underflows++;
      return _filler();
    }
    final packet = _queue.removeFirst();
    final output = SipRtpPacket(
      payloadType: packet.payloadType,
      sequence: packet.sequence + _sequenceOffset,
      timestamp: packet.timestamp + _timeOffset,
      ssrc: packet.ssrc,
      payload: packet.payload,
      marker: packet.marker,
    );
    _last = output;
    sent++;
    return output;
  }

  SipRtpPacket? _filler() {
    final last = _last;
    if (last == null ||
        last.payloadType != audioPayloadType ||
        last.payload.length != 160) {
      return null;
    }
    _sequenceOffset++;
    _timeOffset += 160;
    fillers++;
    sent++;
    return _last = SipRtpPacket(
      payloadType: audioPayloadType,
      sequence: (last.sequence + 1) & 0xffff,
      timestamp: (last.timestamp + 160) & 0xffffffff,
      ssrc: last.ssrc,
      payload: Uint8List(160)..fillRange(0, 160, silenceByte),
    );
  }
}

class RtpDeadlinePacer {
  int? _next;
  int maxLagMicros = 0;
  int delayMicros(int now) => ((_next ?? now) - now).clamp(0, 20000);
  void sentAt(int now) {
    final scheduled = _next ?? now;
    final lag = (now - scheduled).clamp(0, 100000000);
    if (lag > maxLagMicros) maxLagMicros = lag;
    _next = lag > 20000 ? now + 20000 : scheduled + 20000;
  }
}
