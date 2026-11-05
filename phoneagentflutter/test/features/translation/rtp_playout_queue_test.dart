import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/sip/rtp_playout_queue.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_rtp_packet.dart';

SipRtpPacket frame(int sequence, {int type = 0}) => SipRtpPacket(
  payloadType: type,
  sequence: sequence,
  timestamp: sequence * 160,
  ssrc: 4,
  payload: Uint8List(type == 0 ? 160 : 4),
);
void main() {
  test(
    'guard, underflow and recovery keep audio/DTMF sequence and timestamp continuous',
    () {
      final queue = RtpPlayoutQueue(audioPayloadType: 0, silenceByte: 255);
      queue.enqueue(frame(0));
      expect(queue.next(0), null);
      queue.enqueue(frame(1));
      queue.enqueue(frame(2));
      expect(queue.next(20)!.sequence, 0);
      expect(queue.next(40)!.sequence, 1);
      expect(queue.next(60)!.sequence, 2);
      final silence = queue.next(80)!;
      expect(silence.sequence, 3);
      expect(silence.timestamp, 480);
      expect(silence.payload.every((x) => x == 255), true);
      queue.enqueue(frame(3));
      queue.enqueue(frame(4));
      queue.enqueue(frame(5, type: 101));
      expect(queue.next(100)!.sequence, 4);
      expect(queue.next(120)!.timestamp, 800);
      final tone = queue.next(140)!;
      expect(tone.payloadType, 101);
      expect(tone.sequence, 6);
      expect(tone.timestamp, 960);
      expect(queue.next(160), null); // Never synthesize telephone events.
      expect(queue.underflows, 2);
      expect(queue.fillers, 1);
    },
  );
  test('short stream starts after finite guard, overflow is bounded', () {
    final queue = RtpPlayoutQueue(audioPayloadType: 0, silenceByte: 255);
    queue.enqueue(frame(0));
    expect(queue.next(0), null);
    expect(queue.next(60)!.sequence, 0);
    for (var i = 0; i < 100; i++) {
      expect(queue.enqueue(frame(i + 1)), true);
    }
    expect(queue.enqueue(frame(101)), false);
  });
  test('deadline recovers late clock without burst catchup', () {
    final pacer = RtpDeadlinePacer();
    pacer.sentAt(0);
    expect(pacer.delayMicros(10000), 10000);
    pacer.sentAt(200000);
    expect(pacer.maxLagMicros, 180000);
    expect(pacer.delayMicros(200000), 20000);
  });
}
