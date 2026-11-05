import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phone_agent/features/attachments/data/mlkit_ocr_recognizer.dart';
import 'package:phone_agent/features/attachments/data/platform_ocr_image_source.dart';
import 'package:phone_agent/features/attachments/domain/ocr_image_source.dart';
import 'package:phone_agent/features/attachments/domain/ocr_persistence.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('google_mlkit_text_recognizer');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });
  Matcher failure(OcrImageFailure reason) =>
      isA<OcrImageException>().having((e) => e.reason, 'reason', reason);

  test(
    'single gallery selection requests no full metadata; read is deferred',
    () async {
      final file = _File(3, [
        Uint8List.fromList([1, 2, 3]),
      ]);
      final picker = _Picker(file);
      final image = await PlatformOcrImageSource(picker: picker).pick();
      expect(picker.source, ImageSource.gallery);
      expect(picker.metadata, false);
      expect(picker.lostChecks, 1);
      expect(file.reads, 0);
      expect(image!.mimeType, 'image/png');
      expect(await image.read(), [1, 2, 3]);
    },
  );
  test('iOS cancellation does not query Android lost data', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final picker = _Picker(null);
    expect(await PlatformOcrImageSource(picker: picker).pick(), isNull);
    expect(picker.lostChecks, 0);
  });
  test(
    'lost Android selection is consumed but never attached to new session',
    () async {
      final picker = _Picker(null, lost: true);
      await expectLater(
        PlatformOcrImageSource(picker: picker).pick(),
        throwsA(failure(OcrImageFailure.interrupted)),
      );
      expect(picker.source, isNull);
    },
  );
  for (final entry in {
    0: OcrImageFailure.empty,
    ocrMaxImageBytes + 1: OcrImageFailure.tooLarge,
  }.entries) {
    test('invalid size ${entry.key} is rejected before reading', () async {
      final file = _File(entry.key, []);
      await expectLater(
        PlatformOcrImageSource(picker: _Picker(file)).pick(),
        throwsA(failure(entry.value)),
      );
      expect(file.reads, 0);
    });
  }
  test('unsupported image format is not read', () async {
    final file = _File(1, [], name: 'animation.gif');
    await expectLater(
      PlatformOcrImageSource(picker: _Picker(file)).pick(),
      throwsA(failure(OcrImageFailure.unsupported)),
    );
    expect(file.reads, 0);
  });
  test('stream length change fails closed', () async {
    final image = await PlatformOcrImageSource(
      picker: _Picker(_File(1, [Uint8List(2)])),
    ).pick();
    await expectLater(
      image!.read(),
      throwsA(failure(OcrImageFailure.interrupted)),
    );
  });
  test('stream exceeding cap fails before retaining oversized chunk', () async {
    final image = await PlatformOcrImageSource(
      picker: _Picker(_File(1, [Uint8List(ocrMaxImageBytes + 1)])),
    ).pick();
    await expectLater(
      image!.read(),
      throwsA(failure(OcrImageFailure.tooLarge)),
    );
  });
  test('unsupported platform invokes neither picker nor recognizer', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final picker = _Picker(null);
    await expectLater(
      PlatformOcrImageSource(picker: picker).pick(),
      throwsA(failure(OcrImageFailure.unavailable)),
    );
    await expectLater(
      const MlkitOcrRecognizer().recognize('/synthetic.png'),
      throwsA(failure(OcrImageFailure.unavailable)),
    );
    expect(picker.source, isNull);
  });
  test(
    'Chinese recognizer preserves trimmed block/line order and closes',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'vision#closeTextRecognizer') return null;
        return {
          'text': '  首行\n末行  ',
          'blocks': [
            _block([' 首行 ', '   ']),
            _block([' 末行 ']),
          ],
        };
      });
      final result = await const MlkitOcrRecognizer().recognize(
        '/synthetic.png',
      );
      expect(result.rawText, '首行\n末行');
      expect(result.segments, ['首行', '末行']);
      expect(calls.first.arguments['script'], 1);
      expect(calls.first.arguments['imageData']['path'], '/synthetic.png');
      expect(calls.last.method, 'vision#closeTextRecognizer');
      expect(calls.last.arguments['id'], calls.first.arguments['id']);
    },
  );
  test('native error still releases recognition resources', () async {
    var closed = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'vision#closeTextRecognizer') {
        closed = true;
        return null;
      }
      throw PlatformException(code: 'recognition_failed');
    });
    await expectLater(
      const MlkitOcrRecognizer().recognize('/synthetic.png'),
      throwsA(isA<PlatformException>()),
    );
    expect(closed, true);
  });
}

Map<String, Object> _block(List<String> lines) => {
  'text': lines.join('\n'),
  'rect': {'left': 0.0, 'top': 0.0, 'right': 1.0, 'bottom': 1.0},
  'recognizedLanguages': <String>[],
  'points': <Object>[],
  'lines': [
    for (final text in lines)
      {
        'text': text,
        'rect': {'left': 0.0, 'top': 0.0, 'right': 1.0, 'bottom': 1.0},
        'recognizedLanguages': <String>[],
        'points': <Object>[],
        'elements': <Object>[],
      },
  ],
};

class _Picker extends ImagePicker {
  _Picker(this.file, {this.lost = false});
  final XFile? file;
  final bool lost;
  int lostChecks = 0;
  ImageSource? source;
  bool? metadata;
  @override
  Future<LostDataResponse> retrieveLostData() async {
    lostChecks++;
    return lost
        ? LostDataResponse(exception: PlatformException(code: 'lost'))
        : LostDataResponse.empty();
  }

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    this.source = source;
    metadata = requestFullMetadata;
    return file;
  }
}

class _File extends XFile {
  _File(this.size, this.chunks, {String name = 'synthetic.png'})
    : super('/synthetic/$name');
  final int size;
  final List<Uint8List> chunks;
  int reads = 0;
  @override
  Future<int> length() async => size;
  @override
  Stream<Uint8List> openRead([int? start, int? end]) {
    reads++;
    return Stream.fromIterable(chunks);
  }
}
