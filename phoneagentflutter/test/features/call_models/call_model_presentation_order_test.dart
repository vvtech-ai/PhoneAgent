import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/call_models/data/api_call_model_repository.dart';
import 'package:phone_agent/features/call_models/domain/call_models.dart';
import 'package:phone_agent/features/call_models/domain/call_model_quality.dart';
import 'package:phone_agent/features/call_models/presentation/controller/call_model_controller.dart';
import 'package:phone_agent/features/call_models/presentation/pages/call_models_page.dart';
import 'package:phone_agent/features/call_models/presentation/widgets/native_model_card.dart';

CallModelCatalog _catalog(List<String> order) =>
    ApiCallModelRepository.catalog({
      'activeModelId': 'qwen',
      'providers': [
        for (final id in order)
          {
            'modelId': id,
            'displayName': id,
            'available': id != 'locked',
            'active': id == 'qwen',
            'recommended': id == 'seeduplex',
          },
      ],
    });

void main() {
  test(
    'SDK order is preserved independently from the active and recommended models',
    () {
      final catalog = _catalog(['index', 'locked', 'seeduplex', 'qwen']);
      expect(catalog.models.map((model) => model.id), [
        'index',
        'locked',
        'seeduplex',
        'qwen',
      ]);
      expect(catalog.current!.id, 'qwen');
      expect(catalog.models[2].recommended, isTrue);
      expect(catalog.models[1].available, isFalse);
    },
  );

  for (final task in [false, true]) {
    testWidgets(
      '${task ? 'task' : 'home'} selection survives refreshed directory order and latency',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        Future<void> show(List<String> order, int latency) => tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CallModelsPage(
                sheet: true,
                state: CallModelState(catalog: _catalog(order)),
                selectedModelId: task ? 'seeduplex' : null,
                readings: {
                  'index': CallModelReading.probe(
                    available: true,
                    latencyMs: latency,
                  ),
                  'qwen': CallModelReading.probe(
                    available: true,
                    latencyMs: 10,
                  ),
                },
                onBack: () {},
                onRetry: () {},
                onSelect: (_) {},
                onVoices: (_) {},
              ),
            ),
          ),
        );
        for (final order in [
          ['index', 'locked', 'seeduplex', 'qwen'],
          ['locked', 'qwen', 'index', 'seeduplex'],
        ]) {
          await show(order, order.first == 'index' ? 130 : 5);
          final cards = tester
              .widgetList<NativeModelCard>(find.byType(NativeModelCard))
              .toList();
          expect(cards.map((card) => card.model.id), order);
          expect(
            cards.singleWhere((card) => card.selected).model.id,
            task ? 'seeduplex' : 'qwen',
          );
          expect(
            cards
                .singleWhere((card) => card.model.id == 'locked')
                .model
                .available,
            isFalse,
          );
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}
