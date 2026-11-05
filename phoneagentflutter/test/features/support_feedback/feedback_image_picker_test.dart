import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phone_agent/features/support_feedback/data/feedback_image_picker.dart';
import 'package:phone_agent/features/support_feedback/data/feedback_image_processor.dart';

class SelectedImages extends ImagePicker {
  SelectedImages(this.count);
  final int count;
  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async => List.generate(count, (i) => XFile('not-read-$i'));
}

void main() {
  for (final remaining in [1, 3, 6]) {
    test(
      'over-selection explains rejection and remaining $remaining',
      () async {
        final picker = FeedbackImagePicker(
          SelectedImages(remaining + 1),
          FeedbackImageProcessor(),
        );
        await expectLater(
          picker.pick(remaining),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              '本次选择的图片超过可添加数量，最多还能添加$remaining张。',
            ),
          ),
        );
      },
    );
  }
  test('cancelled album returns no changes', () async {
    final picker = FeedbackImagePicker(
      SelectedImages(0),
      FeedbackImageProcessor(),
    );
    expect(await picker.pick(6), isEmpty);
  });
}
