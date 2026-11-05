import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/sip/doubao_protobuf.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_lease.dart';

void main() {
  test('native event field and protobuf wire bytes match fixed fixtures', () {
    final writer = DoubaoProtoWriter()..integer(2, 100);
    expect(writer.build(), [16, 100]);
    final response = DoubaoProtoResponse.decode(
      Uint8List.fromList([10, 5, 24, 128, 218, 196, 9, 16, 150, 1]),
    );
    expect(response.event, 150);
    expect(response.status, 20000000);
  });
  test('audio/text fields and unknown fixed32 field preserve content', () {
    final response = DoubaoProtoResponse.decode(
      Uint8List.fromList([
        16,
        224,
        2,
        26,
        2,
        1,
        0,
        34,
        2,
        72,
        105,
        77,
        0,
        0,
        0,
        0,
      ]),
    );
    expect(response.event, 352);
    expect(response.audio, [1, 0]);
    expect(response.text, 'Hi');
  });
  test('truncated length and varint, invalid tag cannot escape bounds', () {
    for (final value in [
      [10, 200, 1, 0],
      [16, 128],
      [0],
      [15],
      [10, 1, 24],
    ]) {
      expect(
        () => DoubaoProtoResponse.decode(Uint8List.fromList(value)),
        throwsA(isA<SipLeaseFailure>()),
      );
    }
  });
}
