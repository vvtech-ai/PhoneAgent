import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;
import '../domain/feedback.dart';

class FeedbackImageProcessor {
  Future<FeedbackImage> prepare(Uint8List original) async {
    if (original.isEmpty || original.length > 10 * 1024 * 1024) {
      throw const FormatException('单张原图不能超过10 MB');
    }
    final type = _type(original);
    final buffer = await ui.ImmutableBuffer.fromUint8List(original);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? decoded;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final scale =
          2048 /
          (descriptor.width > descriptor.height
              ? descriptor.width
              : descriptor.height);
      codec = await descriptor.instantiateCodec(
        targetWidth: scale < 1
            ? (descriptor.width * scale).round().clamp(1, 2048)
            : null,
        targetHeight: scale < 1
            ? (descriptor.height * scale).round().clamp(1, 2048)
            : null,
      );
      decoded = (await codec.getNextFrame()).image;
      if (type != null && original.length <= 2 * 1024 * 1024) {
        return FeedbackImage(original, 'feedback.${type.$2}', type.$1);
      }
      final pixels = await decoded.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (pixels == null) throw const FormatException('图片无法处理');
      final jpg = await compute(_jpeg, (
        pixels.buffer.asUint8List(),
        decoded.width,
        decoded.height,
      ));
      return FeedbackImage(jpg, 'feedback.jpg', 'image/jpeg');
    } finally {
      decoded?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }
}

(String, String)? _type(Uint8List bytes) {
  if (bytes.length > 3 &&
      bytes[0] == 255 &&
      bytes[1] == 216 &&
      bytes[2] == 255) {
    return ('image/jpeg', 'jpg');
  }
  if (bytes.length > 8 &&
      listEquals(bytes.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10])) {
    return ('image/png', 'png');
  }
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
    return ('image/webp', 'webp');
  }
  return null;
}

Uint8List _jpeg((Uint8List, int, int) input) {
  var decoded = image.Image.fromBytes(
    width: input.$2,
    height: input.$3,
    bytes: input.$1.buffer,
    numChannels: 4,
  );
  for (final quality in [90, 75, 60, 45]) {
    final bytes = image.encodeJpg(decoded, quality: quality);
    if (bytes.length <= 2 * 1024 * 1024) return bytes;
    decoded = image.copyResize(
      decoded,
      width: (decoded.width * .75).round().clamp(1, 2048),
    );
  }
  throw const FormatException('图片压缩失败，请重新选择');
}
