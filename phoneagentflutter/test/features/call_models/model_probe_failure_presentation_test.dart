import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/call_models/domain/call_model_quality.dart';
import 'package:phone_agent/features/call_models/presentation/controller/call_model_quality_controller.dart';
import 'package:phone_agent/features/call_models/presentation/widgets/call_model_latency_pill.dart';
import 'package:phone_agent/features/call_models/presentation/widgets/native_model_card.dart';
import 'package:phone_agent/features/call_models/domain/call_models.dart';

class _FailedProbe implements CallModelQualityRepository {
  @override
  Future<Map<String, CallModelReading>> refresh() async =>
      throw StateError('network');
}

void main() {
  testWidgets(
    'complete model card keeps unknown latency distinct from server selection denial',
    (tester) async {
      var selections = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NativeModelCard(
              model: const CallModel(
                id: 'audio31',
                name: 'Qwen Audio 3.1',
                description: '',
                available: false,
                active: false,
                status: '当前模型尚未接入',
              ),
              quick: true,
              reading: const CallModelReading.unknown(),
              selected: false,
              busy: false,
              onSelect: () => selections++,
            ),
          ),
        ),
      );
      expect(find.bySemanticsLabel(RegExp('.*模型延迟暂无数据.*')), findsOneWidget);
      expect(find.text('当前模型尚未接入'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('model-audio31')),
        warnIfMissed: false,
      );
      expect(selections, 0);
    },
  );
  testWidgets('failed latency request does not claim all models unavailable', (
    tester,
  ) async {
    final c = CallModelQualityController(_FailedProbe());
    addTearDown(c.dispose);
    await c.refresh(['qwen', 'doubao']);
    await tester.pumpWidget(
      MaterialApp(home: CallModelLatencyPill(sample: c.state.readings['QWEN'])),
    );
    expect(find.text('不可用'), findsNothing);
    expect(find.bySemanticsLabel('模型延迟暂无数据'), findsOneWidget);
  });
  testWidgets('available model without a latency sample is not unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CallModelLatencyPill(
          sample: CallModelReading.probe(available: true, latencyMs: null),
        ),
      ),
    );
    expect(find.text('不可用'), findsNothing);
  });
}
