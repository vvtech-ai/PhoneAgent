import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import '../integration_test/ui_consistency_stage_pages.dart';

void main() {
  testWidgets(
    'formal first flow preserves drafts and returns',
    (tester) async {
      final captures = <String>[];
      await verifyUiConsistencyStage(
        tester,
        capture: (name) async {
          captures.add(name);
        },
      );
      expect(captures, hasLength(14));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );
}
