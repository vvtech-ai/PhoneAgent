import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/cross_border_translation_call.dart';

void main() {
  for (final (enabled, caller, callee, expected) in [
    (true, 'CN', 'JP', true),
    (true, ' cn ', 'US', true),
    (true, 'CN', 'cn', false),
    (false, 'CN', 'JP', false),
    (true, null, 'JP', false),
    (true, 'CN', '', false),
    (true, ' ', 'JP', false),
    (true, 'US', null, false),
  ]) {
    test('$enabled $caller -> $callee requires confirmation=$expected', () {
      expect(
        shouldConfirmCrossBorderTranslationCall(
          translationEnabled: enabled,
          callerCountryIso: caller,
          calleeCountryIso: callee,
        ),
        expected,
      );
    });
  }
}
