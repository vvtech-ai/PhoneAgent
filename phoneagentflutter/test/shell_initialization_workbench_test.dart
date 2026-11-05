import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../integration_test/initialization_stage_pages.dart';

void main() {
  for (final width in [320.0, 430.0]) {
    for (final skip in [false, true]) {
      testWidgets(
        'formal entry width=$width historical skip=$skip goes directly to home',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final captures = <String>[];
          await verifyInitializationStage(
            tester,
            skip: skip,
            capture: (name) async => captures.add(name),
          );
          expect(captures, hasLength(3));
        },
      );
    }
  }
}
