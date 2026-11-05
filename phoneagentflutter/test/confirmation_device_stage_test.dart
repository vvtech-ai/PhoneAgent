import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../integration_test/confirmation_stage_pages.dart';

void main() {
  for (final size in [const Size(375, 667), const Size(393, 820)]) {
    testWidgets(
      'confirmation device preflight $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final captures = <String>[];
        await verifyConfirmationStage(
          tester,
          capture: (name) async => captures.add(name),
        );
        expect(captures.toSet(), hasLength(6));
        expect(tester.takeException(), isNull);
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );
  }
}
