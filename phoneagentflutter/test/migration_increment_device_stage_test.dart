import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../integration_test/migration_increment_stage_pages.dart';

void main() {
  for (final size in [const Size(375, 667), const Size(393, 820)]) {
    testWidgets(
      'increment device preflight $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final forbidden = guardMigrationIncrement();
        final captures = <String>[];
        await verifyMigrationIncrement(
          tester,
          capture: (name) async {
            expect(tester.takeException(), isNull);
            captures.add(name);
          },
        );
        expect(
          captures.toSet(),
          hasLength(
            Theme.of(tester.element(find.byType(Scaffold).first)).platform ==
                    TargetPlatform.android
                ? 27
                : 4,
          ),
        );
        expect(forbidden, isEmpty);
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );
  }
}
