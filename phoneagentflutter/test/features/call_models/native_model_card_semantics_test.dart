import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/call_models/domain/call_models.dart';
import 'package:phone_agent/features/call_models/presentation/widgets/native_model_card.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform model and voice actions remain separate', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var choices = 0, voices = 0;
      Future<void> show(bool selected, bool busy) => tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Scaffold(
            body: NativeModelCard(
              model: const CallModel(
                id: 'QWEN_OMNI_PLUS',
                name: 'QwenOmniPlus',
                description: '测试模型',
                available: true,
                active: true,
                multiplier: 1,
              ),
              selected: selected,
              busy: busy,
              onSelect: () => choices++,
              onVoices: () => voices++,
            ),
          ),
        ),
      );
      Future<void> action(Finder finder) async {
        final node = tester.getSemantics(finder);
        expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
        tester.binding.performSemanticsAction(
          ui.SemanticsActionEvent(
            viewId: tester.view.viewId,
            nodeId: node.id,
            type: SemanticsAction.tap,
          ),
        );
        await tester.pump();
      }

      final model = find.bySemanticsLabel('QwenOmniPlus，×1.0，测试模型');
      final voice = find.bySemanticsLabel('QwenOmniPlus 的通话声音，支持系统音色和声音克隆');
      await show(true, false);
      expect(find.text('推荐'), findsNothing);
      expect(
        tester.getSemantics(model).hasFlag(SemanticsFlag.isSelected),
        isTrue,
      );
      expect(
        tester
            .getSemantics(model)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isFalse,
      );
      await action(voice);
      expect([choices, voices], [0, 1]);
      await show(false, false);
      await action(model);
      expect([choices, voices], [1, 1]);
      await show(true, true);
      for (final finder in [model, voice]) {
        final node = tester.getSemantics(finder);
        expect(node.hasFlag(SemanticsFlag.isEnabled), isFalse);
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      }
      handle.dispose();
      expect(tester.takeException(), isNull);
    });
  }
}
