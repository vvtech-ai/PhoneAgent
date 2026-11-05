import '../../support/pump_ui_transitions.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/call_models/domain/call_model_quality.dart';
import 'package:phone_agent/features/call_models/presentation/pages/call_models_page.dart';
import '../../../tool/previews/shell_preview.dart';

class _Port implements CallModelQualityRepository {
  final pending = <Completer<Map<String, CallModelReading>>>[];
  @override
  Future<Map<String, CallModelReading>> refresh() {
    final next = Completer<Map<String, CallModelReading>>();
    pending.add(next);
    return next.future;
  }
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform full shell close reopen isolates pending model quality',
      (tester) async {
        final semantics = tester.ensureSemantics();
        List<String> visibleLabels() {
          final labels = <String>[];
          void visit(SemanticsNode node) {
            labels.add(node.label);
            node.visitChildren((child) {
              visit(child);
              return true;
            });
          }

          visit(
            tester
                .binding
                .renderViews
                .single
                .owner!
                .semanticsOwner!
                .rootSemanticsNode!,
          );
          return labels;
        }

        final port = _Port();
        await tester.pumpWidget(ShellPreviewPage(modelQuality: port));
        await tester.pumpUntilUiSettled();
        await tester.tap(find.byKey(const ValueKey('homeVoiceModelChip')));
        await tester.pump(const Duration(milliseconds: 400));
        // The first render establishes the owner; render its refresh state next.
        await tester.pump();
        expect(port.pending.length, 1);
        expect(visibleLabels(), isNot(contains('打开拨号盘')));
        expect(visibleLabels(), isNot(contains(contains('通话模型：QwenOmniPlus'))));
        expect(find.bySemanticsLabel('正在刷新模型状态'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('关闭'));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(CallModelsPage), findsNothing);
        expect(visibleLabels(), contains('打开拨号盘'));
        expect(visibleLabels(), contains(contains('通话模型：QwenOmniPlus')));
        expect(visibleLabels(), contains(contains('×1.0')));
        await tester.tap(find.byKey(const ValueKey('homeVoiceModelChip')));
        await tester.pump(const Duration(milliseconds: 400));
        // The first render establishes the owner; render its refresh state next.
        await tester.pump();
        expect(port.pending.length, 2);
        port.pending.first.complete({
          'QWEN_OMNI_PLUS': CallModelReading.probe(
            available: true,
            latencyMs: 1,
          ),
        });
        await tester.pump();
        expect(find.text('1ms'), findsNothing);
        expect(find.bySemanticsLabel('正在刷新模型状态'), findsOneWidget);
        port.pending.last.complete({
          'QWEN_OMNI_PLUS': CallModelReading.probe(
            available: true,
            latencyMs: 199,
          ),
        });
        await tester.pumpUntilUiSettled();
        expect(find.text('199ms'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('刷新模型状态'));
        await tester.pump();
        expect(port.pending.length, 3);
        await tester.binding.handlePopRoute();
        await tester.pump(const Duration(milliseconds: 400));
        port.pending.last.complete({});
        await tester.pumpUntilUiSettled();
        expect(find.byType(CallModelsPage), findsNothing);
        expect(visibleLabels(), contains('打开拨号盘'));
        expect(visibleLabels(), contains(contains('通话模型：QwenOmniPlus')));
        expect(visibleLabels(), contains(contains('×1.0')));
        expect(
          find.byKey(const ValueKey('homeVoiceModelChip')),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pumpUntilUiSettled();
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
      variant: TargetPlatformVariant({platform}),
    );
  }
}
