import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/call_models/domain/call_models.dart';
import 'package:phone_agent/features/call_models/presentation/widgets/native_model_card.dart';

void main() {
  testWidgets('full model cards reserve the subtitle line when empty', (
    tester,
  ) async {
    Future<double> cardHeight(String description) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NativeModelCard(
              model: CallModel(
                id: 'model',
                name: '模型A',
                description: description,
                available: true,
                active: false,
              ),
              selected: false,
              busy: false,
              onSelect: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      return tester.getSize(find.byType(NativeModelCard)).height;
    }

    final withDescription = await cardHeight('合成模型');
    final withoutDescription = await cardHeight('');
    expect(withoutDescription, withDescription);
    expect(withoutDescription, greaterThanOrEqualTo(74));
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('$platform voice trailing layout scale=$scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var choices = 0, voices = 0;
        Future<void> show(String voice, {bool busy = false}) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: NativeModelCard(
                      model: CallModel(
                        id: 'QWEN_OMNI_PLUS',
                        name: '模型A',
                        description: '合成模型',
                        available: true,
                        active: false,
                        voiceName: voice,
                      ),
                      selected: false,
                      busy: busy,
                      onSelect: () => choices++,
                      onVoices: () => voices++,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        for (final voice in ['', 'Andre', '合成极长音色名称' * 8]) {
          await show(voice);
          final row = find.byKey(const ValueKey('voices-QWEN_OMNI_PLUS'));
          final arrow = find.descendant(of: row, matching: find.text(' ›'));
          expect(
            tester.getRect(arrow).right,
            closeTo(tester.getRect(row).right - 16, 0.1),
          );
          expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
          expect(find.text('支持系统音色和声音克隆'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(row);
          await tester.pump();
        }
        expect([choices, voices], [0, 3]);
        await show('Andre', busy: true);
        await tester.tap(find.byKey(const ValueKey('voices-QWEN_OMNI_PLUS')));
        await tester.pump();
        expect([choices, voices], [0, 3]);
        await show('Andre');
        await tester.tap(find.byKey(const ValueKey('model-QWEN_OMNI_PLUS')));
        await tester.pump();
        expect([choices, voices], [1, 3]);
      });
    }
  }
}
