import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:phone_agent/features/support_feedback/data/feedback_image_processor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final processor = FeedbackImageProcessor();
  test('oversize originals and undecodable images are rejected', () async {
    await expectLater(
      processor.prepare(Uint8List(10 * 1024 * 1024 + 1)),
      throwsFormatException,
    );
    await expectLater(
      processor.prepare(Uint8List.fromList([1, 2, 3])),
      throwsA(anything),
    );
  });
  test('small PNG preview contains the exact submitted bytes', () async {
    final original = image.encodePng(image.Image(width: 8, height: 8));
    final prepared = await processor.prepare(original);
    expect(prepared.mediaType, 'image/png');
    expect(prepared.bytes, original);
  });
  test(
    'device decoded GIF converts to JPEG rather than sending the original',
    () async {
      final prepared = await processor.prepare(
        image.encodeGif(image.Image(width: 8, height: 8)),
      );
      expect(prepared.mediaType, 'image/jpeg');
      expect(prepared.bytes.take(2), [255, 216]);
      expect(image.decodeJpg(prepared.bytes), isNotNull);
    },
  );
  test('PNG over two MiB is processed into a bounded decodable JPEG', () async {
    final random = Random(8);
    final source = image.Image(width: 1100, height: 1100, numChannels: 3);
    for (final pixel in source) {
      pixel.setRgb(
        random.nextInt(256),
        random.nextInt(256),
        random.nextInt(256),
      );
    }
    final original = image.encodePng(source, level: 0);
    expect(original.length, greaterThan(2 * 1024 * 1024));
    final prepared = await processor.prepare(original);
    expect(prepared.bytes.length, lessThanOrEqualTo(2 * 1024 * 1024));
    expect(prepared.mediaType, 'image/jpeg');
    expect(image.decodeJpg(prepared.bytes), isNotNull);
  });
}
