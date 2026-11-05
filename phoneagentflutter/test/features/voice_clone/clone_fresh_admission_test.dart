import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/voice_clone/data/preview_clone_flow.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_creation.dart';
import 'clone_flow_controller_test.dart' show flow, submit;

void main() {
  test(
    'rerecord refresh rejects changed quote while retaining previous candidate',
    () async {
      final ports = PreviewCloneFlow();
      var price = 300;
      var queries = 0;
      final controller = flow(
        ports,
        models: () async {
          queries++;
          return [
            CloneCreationModel(
              cloneEntitled: true,
              id: PreviewCloneFlow.model,
              name: 'Qwen',
              pricePoints: price,
            ),
          ];
        },
      );
      addTearDown(controller.dispose);
      await submit(controller);
      expect(controller.candidateReady, true);
      price = 500;
      await controller.rerecord();
      expect(queries, 2);
      expect(controller.candidateReady, true);
      expect(controller.state.ui.error, contains('价格已更新'));
      expect(ports.candidates.fromVerified, 1);
      expect(controller.launch.model.pricePoints, 300);
      await controller.confirm();
      expect(ports.confirms, 1);
    },
  );
  test(
    'account change during fresh admission prevents authentication and generation',
    () async {
      final ports = PreviewCloneFlow();
      final catalog = Completer<List<CloneCreationModel>>();
      final controller = flow(ports, models: () => catalog.future);
      addTearDown(controller.dispose);
      final submitting = submit(controller);
      await Future<void>.delayed(Duration.zero);
      ports.current = false;
      catalog.complete([
        const CloneCreationModel(
          cloneEntitled: true,
          id: PreviewCloneFlow.model,
          name: 'Qwen',
          pricePoints: 300,
        ),
      ]);
      await submitting;
      expect(ports.candidates.fromVerified, 0);
    },
  );
  test('fresh unavailable model blocks saved-recording generation', () async {
    final ports = PreviewCloneFlow();
    final controller = flow(
      ports,
      start: CloneCreationStart.savedRecording,
      models: () async => [
        const CloneCreationModel(
          cloneEntitled: true,
          id: PreviewCloneFlow.model,
          name: 'Qwen',
          pricePoints: 300,
          available: false,
        ),
      ],
    );
    addTearDown(controller.dispose);
    await controller.start();
    expect(controller.state.ui.error, contains('暂不可用'));
    expect(ports.candidates.fromSaved, 0);
  });
}
