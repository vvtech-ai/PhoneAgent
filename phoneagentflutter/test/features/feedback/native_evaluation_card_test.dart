import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/feedback/domain/call_evaluation.dart';
import 'package:phone_agent/features/feedback/presentation/controller/call_evaluation_controller.dart';
import 'package:phone_agent/features/feedback/presentation/widgets/call_evaluation_card.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform evaluation selection disabled and failure state', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var taps = 0;
      Future<void> show({bool saving = false, String error = ''}) =>
          tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 640),
                  textScaler: TextScaler.linear(2),
                ),
                child: Scaffold(
                  body: CallEvaluationCard(
                    state: CallEvaluationState(
                      saving: saving,
                      error: error,
                      evaluation: const CallEvaluation(
                        target: FeedbackTarget(
                          FeedbackTargetKind.call,
                          'synthetic',
                        ),
                        modelName: '测试模型的较长名称',
                        minimumLatencyMs: 100,
                        maximumLatencyMs: 250,
                        rating: CallRating.good,
                      ),
                    ),
                    onRate: (_) => taps++,
                  ),
                ),
              ),
            ),
          );
      await show();
      final good = find.bySemanticsLabel('好评');
      expect(tester.getSemantics(good).hasFlag(SemanticsFlag.isButton), isTrue);
      expect(
        tester.getSemantics(good).hasFlag(SemanticsFlag.isSelected),
        isTrue,
      );
      expect(tester.getSize(find.byTooltip('好评')), const Size(48, 48));
      final icon = tester.widget<Icon>(find.byIcon(Icons.thumb_up_outlined));
      expect(icon.size, 15);
      expect(icon.color, const Color(0xFF0A84FF));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('差评'));
      expect(taps, 1);
      await show(saving: true);
      expect(
        tester.getSemantics(good).hasFlag(SemanticsFlag.isEnabled),
        isFalse,
      );
      expect(
        tester
            .getSemantics(good)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isFalse,
      );
      await tester.tap(find.byTooltip('好评'));
      expect(taps, 1);
      await show(error: '评价提交失败，请重试');
      final error = tester.widget<Text>(find.text('评价提交失败，请重试'));
      expect(error.style!.fontSize, 10);
      expect(error.style!.color, const Color(0xFFD92D20));
      expect(
        tester.getSemantics(good).hasFlag(SemanticsFlag.isSelected),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
}
