import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/voice_clone/data/preview_clone_creation_port.dart';
import 'package:phone_agent/features/voice_clone/presentation/widgets/clone_creation_sheet.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final large in [false, true]) {
      testWidgets(
        '$platform picker named close survives reentry large=$large',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          if (large) {
            tester.platformDispatcher.textScaleFactorTestValue = 2;
          }
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final semantics = tester.ensureSemantics();
          try {
            await tester.pumpWidget(
              MaterialApp(
                home: Builder(
                  builder: (root) => Scaffold(
                    body: TextButton(
                      onPressed: () => showCloneCreationSheet(
                        root,
                        PreviewCloneCreationPort(CloneCreationScenario.absent),
                      ),
                      child: const Text('打开'),
                    ),
                  ),
                ),
              ),
            );
            await tester.tap(find.text('打开'));
            await tester.pumpAndSettle();
            final action = find.bySemanticsLabel('关闭克隆模型选择');
            final node = tester.getSemantics(action);
            expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
            expect(
              node.getSemanticsData().hasAction(SemanticsAction.tap),
              isTrue,
            );
            expect(tester.getSize(action), const Size(48, 48));
            expect(
              tester.widget<Text>(find.text('×')).textScaler,
              TextScaler.noScaling,
            );
            final old = tester
                .widget<IconButton>(find.byType(IconButton))
                .onPressed!;
            old();
            old();
            await tester.pumpAndSettle();
            expect(find.byType(CloneCreationSheet), findsNothing);
            expect(find.text('打开'), findsOneWidget);
            await tester.tap(find.text('打开'));
            await tester.pumpAndSettle();
            old();
            await tester.pumpAndSettle();
            expect(find.byType(CloneCreationSheet), findsOneWidget);
            await tester.tap(action);
            await tester.pumpAndSettle();
            expect(find.byType(CloneCreationSheet), findsNothing);
            expect(find.text('打开'), findsOneWidget);
            expect(tester.takeException(), isNull);
          } finally {
            await tester.pumpWidget(const SizedBox());
            await tester.pumpAndSettle();
            semantics.dispose();
          }
        },
        variant: TargetPlatformVariant({platform}),
      );
    }
  }
}
