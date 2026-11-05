import '../../support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation_history/presentation/controller/recording_audio_controller.dart';
import 'package:phone_agent/features/translation_history/presentation/widgets/recording_audio_card.dart';
import '../../../tool/previews/shell_preview.dart';

List<SemanticsNode> _visibleNodes(WidgetTester tester) {
  final nodes = <SemanticsNode>[];
  void visit(SemanticsNode node) {
    nodes.add(node);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(
    tester.binding.renderViews.single.owner!.semanticsOwner!.rootSemanticsNode!,
  );
  return nodes;
}

void _button(WidgetTester tester, String label, bool enabled) {
  final node = _visibleNodes(tester).singleWhere(
    (n) =>
        n.label == label &&
        n.getSemanticsData().hasFlag(SemanticsFlag.isButton),
  );
  final data = node.getSemanticsData();
  expect(data.hasFlag(SemanticsFlag.isButton), isTrue);
  expect(data.hasFlag(SemanticsFlag.hasEnabledState), isTrue);
  expect(data.hasFlag(SemanticsFlag.isEnabled), enabled);
  expect(data.hasAction(SemanticsAction.tap), enabled);
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform recording action states have independent semantics',
      (tester) async {
        final semantics = tester.ensureSemantics();
        for (final entry in [
          (
            const RecordingAudioState(phase: RecordingAudioPhase.ready),
            '播放录音',
            true,
            true,
          ),
          (
            const RecordingAudioState(phase: RecordingAudioPhase.playing),
            '暂停录音',
            true,
            true,
          ),
          (
            const RecordingAudioState(
              phase: RecordingAudioPhase.loading,
              busy: true,
            ),
            '录音加载中',
            false,
            true,
          ),
          (
            const RecordingAudioState(
              phase: RecordingAudioPhase.processing,
              busy: true,
            ),
            '录音加载中',
            false,
            false,
          ),
          (
            const RecordingAudioState(
              phase: RecordingAudioPhase.ready,
              saving: true,
            ),
            '播放录音',
            false,
            false,
          ),
          (
            const RecordingAudioState(phase: RecordingAudioPhase.failed),
            '重试加载录音',
            true,
            true,
          ),
        ]) {
          var plays = 0, saves = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Scaffold(
                body: RecordingAudioCard(
                  state: entry.$1,
                  onPrimary: () => plays++,
                  onSave: () => saves++,
                ),
              ),
            ),
          );
          await tester.pump();
          _button(tester, entry.$2, entry.$3);
          _button(tester, '保存录音', entry.$4);
          if (entry.$3) await tester.tap(find.bySemanticsLabel(entry.$2));
          if (entry.$4) await tester.tap(find.bySemanticsLabel('保存录音'));
          expect(plays, entry.$3 ? 1 : 0);
          expect(saves, entry.$4 ? 1 : 0);
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox());
        semantics.dispose();
      },
    );

    testWidgets(
      '$platform formal receipt exposes play pause and save separately',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(393, 820);
        addTearDown(tester.view.reset);
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(const ShellPreviewPage());
        await tester.pumpUntilUiSettled();
        await tester.tap(find.byKey(const ValueKey('tab-2')));
        await tester.pumpUntilUiSettled();
        await tester.tap(
          find.byKey(const ValueKey('conversation:mock-receipt-single')),
        );
        await tester.pumpUntilUiSettled();
        await tester.ensureVisible(
          find.byKey(const ValueKey('recording-primary')),
        );
        await tester.pumpUntilUiSettled();
        if (find
            .byKey(const ValueKey('recording-primary'))
            .hitTestable()
            .evaluate()
            .isEmpty) {
          await tester.ensureVisible(
            find.byKey(const ValueKey('recording-primary')),
          );
          await tester.pumpUntilUiSettled();
        }
        expect(
          find.byKey(const ValueKey('recording-primary')).hitTestable(),
          findsOneWidget,
        );
        _button(tester, '播放录音', true);
        _button(tester, '保存录音', true);
        await tester.tap(find.bySemanticsLabel('播放录音'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        await tester.ensureVisible(
          find.byKey(const ValueKey('recording-primary')),
        );
        await tester.pumpUntilUiSettled();
        _button(tester, '暂停录音', true);
        await tester.tap(find.bySemanticsLabel('暂停录音'));
        await tester.pumpUntilUiSettled();
        _button(tester, '播放录音', true);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpUntilUiSettled();
        semantics.dispose();
      },
      variant: TargetPlatformVariant({platform}),
    );
  }
}
