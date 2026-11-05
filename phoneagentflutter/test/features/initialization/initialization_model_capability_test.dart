import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/initialization/domain/initialization_gateway.dart';
import 'package:phone_agent/features/initialization/presentation/widgets/initialization_model_cards.dart';

void main() {
  test('only fixed known provider identifiers have capabilities', () {
    for (final id in ['QWEN_OMNI_PLUS', ' qwen_omni_flash ']) {
      expect(InitializationModel(id, '', '').capability, '支持系统音色和声音克隆');
    }
    for (final id in ['DOUBAO_SEEDUPLEX_3_0', 'GPT', 'unknown', '']) {
      expect(InitializationModel(id, '', '').capability, isEmpty);
    }
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets('native known capabilities grow at scale $scale', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: InitializationModelCards(
                    catalog: const InitializationCatalog('QWEN_OMNI_PLUS', [
                      InitializationModel('QWEN_OMNI_PLUS', 'Qwen', '普通模型'),
                      InitializationModel(
                        'DOUBAO',
                        'Seeduplex',
                        '不同通话效果',
                        enabled: false,
                      ),
                      InitializationModel('DOUBAO_SEEDUPLEX_3_0', 'V3', '合成模型'),
                      InitializationModel('unknown', 'Unknown', '未知模型'),
                    ]),
                    selected: 'QWEN_OMNI_PLUS',
                    busy: false,
                    onSelect: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text('支持系统音色和声音克隆'), findsOneWidget);
        expect(find.text('仅支持系统音色'), findsOneWidget);
        final qwen = tester.getSize(
          find.byKey(const ValueKey('init-model-QWEN_OMNI_PLUS')),
        );
        final unknown = tester.getSize(
          find.byKey(const ValueKey('init-model-unknown')),
        );
        expect(qwen.height, greaterThan(unknown.height));
        if (scale == 1) expect(qwen.height, 86);
        final semantics = tester.getSemantics(
          find.byKey(const ValueKey('init-model-QWEN_OMNI_PLUS')),
        );
        expect(semantics.label, contains('支持系统音色和声音克隆'));
        expect(semantics.hasFlag(SemanticsFlag.isSelected), isTrue);
        expect(tester.takeException(), isNull);
      } finally {
        handle.dispose();
      }
    });
  }
  testWidgets(
    'description already containing exact capability is not repeated',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InitializationModelCards(
              catalog: const InitializationCatalog('DOUBAO', [
                InitializationModel('DOUBAO', 'Seeduplex', '仅支持系统音色'),
              ]),
              selected: 'DOUBAO',
              busy: false,
              onSelect: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('仅支持系统音色'), findsOneWidget);
    },
  );
}
