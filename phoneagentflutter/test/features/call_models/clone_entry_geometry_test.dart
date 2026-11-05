import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/call_models/presentation/widgets/clone_voice_card.dart';
import 'package:phone_agent/features/call_models/presentation/controller/call_model_controller.dart';
import 'package:phone_agent/features/call_models/presentation/widgets/native_clone_entry.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform voice clone compact paint scalable cost and action',
      (tester) async {
        tester.view.physicalSize = const Size(390, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var creates = 0;
        Future<void> show(double scale) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: CloneVoiceCard(
                        state: const CallModelState(
                          voiceProvider: 'QWEN_OMNI_PLUS',
                        ),
                        onSelect: () {},
                        onRefresh: () {},
                        onCreate: () => creates++,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        await show(1);
        final button = find.byKey(const ValueKey('voice-create-clone'));
        expect(
          tester
              .getSize(
                find.descendant(of: button, matching: find.byType(Material)),
              )
              .height,
          50,
        );
        expect(tester.getSize(button).height, greaterThanOrEqualTo(50));
        final star = find.text('✦');
        final normal = tester.getSize(star).height;
        await show(2);
        expect(tester.getSize(star).height, greaterThan(normal * 1.8));
        expect(tester.getSize(button).height, greaterThanOrEqualTo(50));
        await tester.tap(find.bySemanticsLabel('声音克隆，价格暂不可用'));
        await tester.pump();
        expect(creates, 1);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets('$platform clone visual surface and scalable star', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(411, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Future<void> show(double scale) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: NativeCloneEntry(onTap: () {}),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await show(1);
      final action = find.byKey(const ValueKey('model-create-clone'));
      final surface = find.descendant(
        of: action,
        matching: find.byType(Material),
      );
      expect(tester.getSize(surface).height, 50);
      expect(tester.getSize(action).height, greaterThanOrEqualTo(50));
      final star = find.text('✦');
      final normal = tester.getSize(star).height;
      expect(tester.widget<Text>(star).style!.color, const Color(0xFFFFC400));
      await show(2);
      expect(tester.getSize(star).height, greaterThan(normal * 1.8));
      expect(tester.getSize(action).height, greaterThanOrEqualTo(50));
      expect(tester.takeException(), isNull);
    });
  }
}
