import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/data/stream/sse_frame_decoder.dart';

void main() {
  test('single-byte UTF8 splits, CRLF, comments and multi-line data', () async {
    final input = utf8.encode(
      ': ping\r\nevent: text_delta\r\nid: a\r\ndata: {"text":\r\ndata: "你好"}\r\n\r\nevent: done\ndata: {}\n\n',
    );
    final frames = await const SseFrameDecoder()
        .decode(Stream.fromIterable(input.map((b) => [b])))
        .toList();
    expect(frames.length, 2);
    expect(frames.first.event, 'text_delta');
    expect(jsonDecode(frames.first.data), {'text': '你好'});
    expect(frames.last.event, 'done');
  });
  test('bare CR, empty data and split newline work', () async {
    final frames = await const SseFrameDecoder()
        .decode(
          Stream.fromIterable([
            utf8.encode('event: heartbeat\rdata:\r'),
            utf8.encode('\revent: done\rdata: {}\r\r'),
          ]),
        )
        .toList();
    expect(frames.map((e) => e.event), ['heartbeat', 'done']);
    expect(frames.first.data, '');
  });
  test('truncated final data does not fabricate terminal frame', () async {
    final frames = await const SseFrameDecoder()
        .decode(Stream.value(utf8.encode('event: done\ndata: {}')))
        .toList();
    expect(frames, isEmpty);
  });
  test('unbounded unterminated input is rejected', () async {
    await expectLater(
      const SseFrameDecoder(
        maximumFrameCharacters: 12,
      ).decode(Stream.value(utf8.encode('data: ${'x' * 20}'))).toList(),
      throwsFormatException,
    );
  });
}
