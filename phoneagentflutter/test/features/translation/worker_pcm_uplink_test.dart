import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/sip/worker_pcm_uplink.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_rtp_packet.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_sdp.dart';

Map<String, num> config({bool mix = false}) => {
  'sequence': 65534,
  'timestamp': 1000,
  'ssrc': 42,
  'mix': mix ? 1 : 0,
  'ratio': .5,
  'gain': 1,
  'boost': 1,
  'boundary': 1,
};
Uint8List tone(int bytes) {
  final result = Uint8List(bytes), data = ByteData(bytes);
  for (var i = 0; i < bytes; i += 2) {
    data.setInt16(i, 4000, Endian.little);
  }
  result.setAll(0, data.buffer.asUint8List());
  return result;
}

void main() {
  test(
    '160ms PCM prebuffer, one underrun per episode and completed short tail',
    () {
      final sender = WorkerPcmUplink(config(), 0, SipAudioCodec.pcmu);
      sender.enqueue(tone(2560), 0);
      expect(sender.next(0), isNull);
      sender.enqueue(tone(2560), 80);
      for (var i = 0; i < 8; i++) {
        final packet = sender.next(80 + i * 20)!;
        expect(packet.payload.length, 160);
        expect(packet.payload.any((b) => b != 255), true);
        expect(packet.sequence, (65534 + i) & 0xffff);
        expect(packet.timestamp, 1000 + i * 160);
      }
      sender.next(240);
      sender.next(260);
      expect(sender.voiceUnderflows, 1);
      sender.enqueue(tone(320), 280);
      expect(sender.lastWasFiller, true);
      sender.finish(280);
      expect(sender.next(280)!.payload.length, 160);
      expect(sender.lastWasFiller, false);
      sender.next(300);
      sender.next(320);
      expect(sender.voiceUnderflows, 1);
      expect(sender.idleFrames, 2);
      sender.enqueue(tone(320), 400);
      sender.next(400);
      expect(sender.voiceUnderflows, 1); // New short response is prebuffering.
      sender.finish(400);
      sender.next(420);
      expect(sender.maxQueuedMs, 160);
      expect(sender.maxChunkGapMs, 200);
    },
  );
  test('cross-block framing and bounded PCM queue', () {
    final sender = WorkerPcmUplink(config(), 8, SipAudioCodec.pcma);
    sender.enqueue(tone(100), 0);
    sender.enqueue(tone(540), 1);
    sender.finish(2);
    expect(sender.next(2)!.payload.length, 160);
    sender.enqueue(Uint8List(960000), 3);
    expect(() => sender.enqueue(Uint8List(2), 4), throwsA(anything));
  });
  test(
    'original mixing lives in worker; telephone duration retains timestamp',
    () {
      final sender = WorkerPcmUplink(config(mix: true), 0, SipAudioCodec.pcmu);
      sender.enqueue(tone(640), 0, original: true);
      final audio = sender.next(0)!;
      expect(audio.payload.any((b) => b != 255), true);
      final events = SipTelephoneEvent.packets(
        digit: '3',
        payloadType: 101,
        sequence: 0,
        timestamp: 0,
        ssrc: 1,
      ).map(sender.stamp).toList();
      expect(events.map((p) => p.timestamp).toSet(), {1160});
      expect(events.where((p) => p.payload[1] & 128 != 0).length, 3);
      sender.enqueue(tone(640), 200, original: true);
      final resumed = sender.next(200)!;
      expect(resumed.timestamp, 2440);
      expect(resumed.sequence, (events.last.sequence + 1) & 65535);
    },
  );
}
