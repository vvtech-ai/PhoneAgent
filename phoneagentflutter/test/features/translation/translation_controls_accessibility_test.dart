import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/translation_call_view.dart';
import 'package:phone_agent/features/translation/presentation/widgets/translation_call_controls.dart';

void main() {
  testWidgets('screen reader can activate controls; stopping removes actions', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var disposed = false;
    addTearDown(() {
      if (!disposed) handle.dispose();
    });
    var mute = 0;
    Future<void> render(bool stopping) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TranslationCallControls(
            state: TranslationCallView(stopping: stopping),
            onMute: () => mute++,
            onSpeaker: () {},
            onPad: () {},
            onDigit: (_) {},
            onHangup: () {},
          ),
        ),
      ),
    );
    await render(false);
    final finder = find.byKey(const ValueKey('translation-control-静音'));
    final node = tester.getSemantics(finder);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    tester.binding.performSemanticsAction(
      ui.SemanticsActionEvent(
        nodeId: node.id,
        viewId: tester.view.viewId,
        type: SemanticsAction.tap,
      ),
    );
    expect(mute, 1);
    await render(true);
    expect(
      tester
          .getSemantics(finder)
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isFalse,
    );
    handle.dispose();
    disposed = true;
  });
}
