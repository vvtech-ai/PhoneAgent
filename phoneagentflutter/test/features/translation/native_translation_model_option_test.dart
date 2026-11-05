import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/presentation/widgets/translation_latency_pill.dart';
import 'package:phone_agent/features/translation/domain/translation_model_quality.dart';
import 'package:phone_agent/features/translation/presentation/widgets/native_translation_model_option.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('native model information styling $platform', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 350,
                child: NativeTranslationModelOption(
                  name: 'Qwen3.5',
                  subtitle: '翻译体验更稳定，适合大多数通话',
                  selected: true,
                  recommended: true,
                  multiplier: 1.2,
                  onSelect: () {},
                ),
              ),
            ),
          ),
        ),
      );
      final badge = find.byKey(
        const ValueKey('translation-native-recommendation'),
      );
      final radio = find.byKey(const ValueKey('translation-native-radio'));
      final decoration =
          tester.widget<Container>(badge).decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFFEAF3FF));
      final label = tester.widget<Text>(find.text('推荐'));
      expect(label.style!.color, const Color(0xFF1677FF));
      expect(label.style!.fontSize, 11);
      expect(label.style!.fontWeight, FontWeight.bold);
      expect(tester.getTopLeft(radio).dx - tester.getTopRight(badge).dx, 14);
      expect(tester.getSize(find.byType(TranslationLatencyPill)).height, 16);
      if (platform == TargetPlatform.iOS) {
        expect(tester.getSize(badge), const Size(38, 20));
        expect(
          tester.getSize(find.byType(NativeTranslationModelOption)).height,
          64,
        );
        expect(tester.widget<Text>(find.text('翻译体验更稳定，适合大多数通话')).maxLines, 1);
      }
      expect(tester.takeException(), isNull);
    });
    testWidgets('model option geometry, large font and admission $platform', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(240, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      var allowed = false;
      var taps = 0;
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return Scaffold(
                body: SingleChildScrollView(
                  child: NativeTranslationModelOption(
                    name: 'GPT Live Translate',
                    subtitle: '地区未就绪，暂不检测节点',
                    selected: true,
                    multiplier: 1.2,
                    sample: TranslationModelSample.reachable(250),
                    onSelect: allowed ? () => taps++ : null,
                  ),
                ),
              );
            },
          ),
        ),
      );
      final radio = find.byKey(const ValueKey('translation-native-radio'));
      expect(tester.getSize(radio), const Size.square(20));
      final button = find.byType(NativeTranslationModelOption);
      expect(tester.getSize(button).height, greaterThan(100));
      expect(find.bySemanticsLabel('模型延迟一般，250毫秒'), findsOneWidget);
      final card = find.descendant(of: button, matching: find.byType(Material));
      expect(
        (tester.widget<Material>(card).shape as RoundedRectangleBorder)
            .side
            .width,
        1.5,
      );
      await tester.tap(find.text('GPT Live Translate'));
      expect(taps, 0);
      rebuild(() => allowed = true);
      await tester.pump();
      expect(tester.widget<Material>(card).color, const Color(0xFFF8F7FF));
      await tester.tap(find.text('GPT Live Translate'));
      expect(taps, 1);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
}
