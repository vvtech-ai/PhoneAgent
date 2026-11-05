import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/call_models/domain/call_models.dart';
import 'package:phone_agent/features/call_models/domain/call_model_quality.dart';
import 'package:phone_agent/features/call_models/presentation/controller/call_model_controller.dart';
import 'package:phone_agent/features/call_models/presentation/pages/call_models_page.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform model quality 2x refresh and unavailable do not alter admission',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 640);
        addTearDown(tester.view.reset);
        final semantics = tester.ensureSemantics();
        var busy = false;
        var refreshes = 0, selections = 0, closes = 0;
        late StateSetter rebuild;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  rebuild = setState;
                  return CallModelsPage(
                    sheet: true,
                    qualityBusy: busy,
                    state: const CallModelState(
                      catalog: CallModelCatalog('QWEN_OMNI_PLUS', [
                        CallModel(
                          id: 'QWEN_OMNI_PLUS',
                          name: 'QwenOmniPlus',
                          description: '测试模型',
                          available: true,
                          active: true,
                          multiplier: 1,
                        ),
                      ]),
                    ),
                    readings: const {
                      'QWEN_OMNI_PLUS': CallModelReading.unavailable(),
                    },
                    onBack: () => closes++,
                    onRetry: () {},
                    onSelect: (_) => selections++,
                    onVoices: (_) {},
                    onRefreshQuality: () {
                      refreshes++;
                      rebuild(() => busy = true);
                    },
                  );
                },
              ),
            ),
          ),
        );
        expect(find.text('不可用'), findsOneWidget);
        expect(find.text('选择 AI 通话模型'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('刷新模型状态'));
        await tester.pump();
        expect(
          tester.getSemantics(find.bySemanticsLabel('正在刷新模型状态')),
          matchesSemantics(
            label: '正在刷新模型状态',
            isButton: true,
            hasEnabledState: true,
            isEnabled: false,
          ),
        );
        await tester.tap(find.byKey(const ValueKey('model-QWEN_OMNI_PLUS')));
        expect(selections, 1, reason: 'probe quality is not model admission');
        expect(refreshes, 1);
        await tester.tap(find.bySemanticsLabel('关闭'));
        expect(closes, 1);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }
}
