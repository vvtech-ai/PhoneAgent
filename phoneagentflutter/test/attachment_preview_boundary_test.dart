import 'support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/attachments/presentation/widgets/attachment_menu.dart';
import '../tool/previews/migration_workbench.dart';
import '../tool/previews/workbench_catalog.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform formal attachments expose only original choices',
      (tester) async {
        tester.view.physicalSize = const Size(430, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MigrationWorkbench(
            scenes: [workbenchScenes.singleWhere((scene) => scene.id == 'app')],
          ),
        );
        Future<void> tap(Finder target) async {
          await tester.ensureVisible(target);
          await tester.tap(target);
          await tester.pumpUntilUiSettled();
          expect(tester.takeException(), isNull);
        }

        await tester.pumpUntilUiSettled();
        await tap(find.byKey(const ValueKey('scene-app')));
        await tap(find.byKey(const ValueKey('skill-restaurant_booking')));
        await tap(find.bySemanticsLabel('添加图片'));
        expect(find.byType(AttachmentMenu), findsOneWidget);
        expect(find.text('相册'), findsOneWidget);
        expect(find.text('文档'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AttachmentMenu),
            matching: find.textContaining('MOCK'),
          ),
          findsNothing,
        );
        expect(AttachmentChoice.values, [
          AttachmentChoice.album,
          AttachmentChoice.document,
        ]);
      },
      variant: TargetPlatformVariant({platform}),
    );
  }
}
