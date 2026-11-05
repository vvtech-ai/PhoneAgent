import '../../support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/voice_clone/presentation/pages/clone_creation_route.dart';
import 'package:phone_agent/features/call_models/presentation/pages/call_models_page.dart';
import 'package:phone_agent/features/call_models/presentation/pages/call_voices_page.dart';
import '../../../tool/previews/shell_preview.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final large in [false, true]) {
      for (final voice in [false, true]) {
        testWidgets(
          '$platform clone action image-free single route voice=$voice large=$large',
          (tester) async {
            tester.view.physicalSize = const Size(320, 568);
            tester.view.devicePixelRatio = 1;
            if (large) tester.platformDispatcher.textScaleFactorTestValue = 2;
            addTearDown(tester.view.reset);
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            final semantics = tester.ensureSemantics();
            Future<void> tap(String name) async {
              final finder = find.byKey(ValueKey(name));
              if (finder.evaluate().isEmpty) {
                await tester.scrollUntilVisible(
                  finder,
                  160,
                  scrollable: find.byType(Scrollable).last,
                );
              }
              await Scrollable.ensureVisible(
                tester.element(finder),
                alignment: .35,
              );
              await tester.pumpUntilUiSettled();
              await tester.tap(finder);
              await tester.pumpUntilUiSettled();
            }

            try {
              await tester.pumpWidget(const ShellPreviewPage());
              await tester.pumpUntilUiSettled();
              await tap('tab-3');
              await tap('settings-models');
              if (voice) await tap('voices-QWEN_OMNI_PLUS');
              final entry = find.descendant(
                of: voice
                    ? find.byType(CallVoicesPage)
                    : find.byType(CallModelsPage),
                matching: find.bySemanticsLabel('声音克隆，650积分'),
              );
              await Scrollable.ensureVisible(
                tester.element(entry),
                alignment: .35,
              );
              await tester.pumpUntilUiSettled();
              final rootNodes = <SemanticsNode>[];
              void collect(SemanticsNode value) {
                rootNodes.add(value);
                value.visitChildren((child) {
                  collect(child);
                  return true;
                });
              }

              collect(
                tester
                    .binding
                    .renderViews
                    .single
                    .owner!
                    .semanticsOwner!
                    .rootSemanticsNode!,
              );
              expect(
                rootNodes.where(
                  (node) =>
                      node.label == '声音克隆，650积分' &&
                      node.hasFlag(SemanticsFlag.isButton),
                ),
                hasLength(1),
              );
              final node = tester.getSemantics(entry);
              expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
              expect(node.hasFlag(SemanticsFlag.isEnabled), isTrue);
              expect(node.hasFlag(SemanticsFlag.isImage), isFalse);
              expect(
                node.getSemanticsData().hasAction(SemanticsAction.tap),
                isTrue,
              );
              expect(tester.getSize(entry).height, greaterThanOrEqualTo(48));
              final button = find.descendant(
                of: entry,
                matching: find.byType(FilledButton),
              );
              final callback = tester.widget<FilledButton>(button).onPressed!;
              callback();
              callback();
              await tester.pumpUntilUiSettled();
              expect(
                find.byType(CloneCreationRoute, skipOffstage: false),
                findsOneWidget,
              );
              expect(
                find.text('选择声音克隆模型'),
                voice ? findsNothing : findsOneWidget,
              );
              expect(find.text('开始认证'), voice ? findsOneWidget : findsNothing);
              callback();
              await tester.pumpUntilUiSettled();
              expect(
                find.byType(CloneCreationRoute, skipOffstage: false),
                findsOneWidget,
              );
              if (voice) {
                await tester.binding.handlePopRoute();
              } else {
                await tester.tap(find.byTooltip('关闭'));
              }
              await tester.pumpUntilUiSettled();
              expect(find.byType(CloneCreationRoute), findsNothing);
              expect(find.byType(CallModelsPage), findsOneWidget);
              if (voice) {
                callback();
                await tester.pumpUntilUiSettled();
                expect(find.byType(CloneCreationRoute), findsNothing);
              }
              expect(tester.takeException(), isNull);
            } finally {
              await tester.pumpWidget(const SizedBox());
              await tester.pumpUntilUiSettled();
              semantics.dispose();
            }
          },
          variant: TargetPlatformVariant({platform}),
        );
      }
    }
  }
}
