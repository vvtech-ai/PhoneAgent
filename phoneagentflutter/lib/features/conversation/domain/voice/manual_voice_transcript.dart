import 'spoken_phone_number.dart';

/// v65 overlap rules and v66 spoken phone digits; not sentence guessing.
class ManualVoiceTranscript {
  String buffered = '', display = '';
  static final _metadata = RegExp(
    r'[A-Za-z][A-Za-z0-9]*-[A-Za-z][A-Za-z0-9]*v?\d+\.\d+',
    caseSensitive: false,
  );
  static bool valid(String text) =>
      text.trim().isNotEmpty && !_metadata.hasMatch(text.trim());

  static String merge(String left, String right) {
    left = left.trim();
    right = right.trim();
    if (left.isEmpty) return right;
    if (right.isEmpty || left == right || left.endsWith(right)) return left;
    if (right.startsWith(left)) return right;
    for (
      var size = left.length < right.length ? left.length : right.length;
      size > 0;
      size--
    ) {
      if (left.endsWith(right.substring(0, size))) {
        return left + right.substring(size);
      }
    }
    return '$left $right';
  }

  void partial(String text) {
    if (text.trim().isNotEmpty) {
      display = SpokenPhoneNumber.normalize(
        merge(buffered, SpokenPhoneNumber.normalize(text)),
      );
    }
  }

  bool finalText(String text) {
    if (!valid(text)) return false;
    display = buffered = SpokenPhoneNumber.normalize(
      merge(buffered, SpokenPhoneNumber.normalize(text)),
    );
    return true;
  }

  String get releaseText {
    final text = merge(buffered, display);
    return valid(text) ? text : '';
  }

  String get timeoutText {
    final text =
        buffered.isNotEmpty &&
            !(display.length > buffered.length && display.contains(buffered))
        ? buffered
        : display;
    return valid(text) ? text : '';
  }
}
