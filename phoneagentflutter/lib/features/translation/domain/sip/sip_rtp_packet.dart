import 'dart:typed_data';
import 'sip_lease.dart';

class SipRtpPacket {
  const SipRtpPacket({
    required this.payloadType,
    required this.sequence,
    required this.timestamp,
    required this.ssrc,
    required this.payload,
    this.marker = false,
  });
  final int payloadType, sequence, timestamp, ssrc;
  final Uint8List payload;
  final bool marker;

  Uint8List encode() {
    if (payloadType < 0 || payloadType > 127 || payload.length > 65495) {
      throw const SipLeaseFailure('INVALID_RTP');
    }
    final bytes = Uint8List(12 + payload.length);
    final data = ByteData.sublistView(bytes);
    bytes[0] = 0x80;
    bytes[1] = (marker ? 0x80 : 0) | payloadType;
    data.setUint16(2, sequence & 0xffff);
    data.setUint32(4, timestamp & 0xffffffff);
    data.setUint32(8, ssrc & 0xffffffff);
    bytes.setRange(12, bytes.length, payload);
    return bytes;
  }

  static SipRtpPacket? parse(Uint8List bytes) {
    if (bytes.length < 12 || bytes[0] >> 6 != 2) return null;
    final data = ByteData.sublistView(bytes);
    var start = 12 + (bytes[0] & 0xf) * 4;
    if (bytes.length < start) return null;
    if ((bytes[0] & 0x10) != 0) {
      if (bytes.length < start + 4) return null;
      start += 4 + data.getUint16(start + 2) * 4;
    }
    var end = bytes.length;
    if ((bytes[0] & 0x20) != 0) {
      final padding = bytes.last;
      if (padding == 0 || padding > end - start) return null;
      end -= padding;
    }
    if (start > end) return null;
    return SipRtpPacket(
      payloadType: bytes[1] & 0x7f,
      marker: (bytes[1] & 0x80) != 0,
      sequence: data.getUint16(2),
      timestamp: data.getUint32(4),
      ssrc: data.getUint32(8),
      payload: Uint8List.fromList(bytes.sublist(start, end)),
    );
  }
}

abstract final class SipTelephoneEvent {
  static List<SipRtpPacket> packets({
    required String digit,
    required int payloadType,
    required int sequence,
    required int timestamp,
    required int ssrc,
    int durationMs = 160,
  }) {
    if (!RegExp(r'^[0-9*#]$').hasMatch(digit) ||
        payloadType < 0 ||
        payloadType > 127 ||
        durationMs < 20 ||
        durationMs > 8000) {
      throw const SipLeaseFailure('INVALID_DTMF');
    }
    final event = digit == '*'
        ? 10
        : digit == '#'
        ? 11
        : int.parse(digit);
    final packets = <SipRtpPacket>[];
    void add(int duration, bool end) {
      final payload = Uint8List.fromList([
        event,
        (end ? 0x80 : 0) | 10,
        duration >> 8,
        duration & 0xff,
      ]);
      packets.add(
        SipRtpPacket(
          payloadType: payloadType,
          sequence: (sequence + packets.length) & 0xffff,
          timestamp: timestamp,
          ssrc: ssrc,
          payload: payload,
          marker: packets.isEmpty,
        ),
      );
    }

    for (var elapsed = 20; elapsed < durationMs; elapsed += 20) {
      add(elapsed * 8, false);
    }
    for (var i = 0; i < 3; i++) {
      add(durationMs * 8, true);
    }
    return List.unmodifiable(packets);
  }
}
