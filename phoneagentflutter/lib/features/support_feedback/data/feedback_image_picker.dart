import 'package:image_picker/image_picker.dart';
import '../domain/feedback.dart';
import 'feedback_image_processor.dart';

class FeedbackImagePicker {
  FeedbackImagePicker(this.picker, this.processor);
  final ImagePicker picker;
  final FeedbackImageProcessor processor;
  Future<List<FeedbackImage>> pick(int remaining) async {
    final files = await picker.pickMultiImage();
    if (files.length > remaining) {
      throw FormatException('本次选择的图片超过可添加数量，最多还能添加$remaining张。');
    }
    final images = <FeedbackImage>[];
    for (final file in files) {
      if (await file.length() > 10 * 1024 * 1024) {
        throw const FormatException('单张原图不能超过10 MB');
      }
      images.add(await processor.prepare(await file.readAsBytes()));
    }
    return images;
  }
}
