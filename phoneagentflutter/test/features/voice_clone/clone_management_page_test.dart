import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/features/call_models/presentation/widgets/native_voice_selection_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/voice_clone/presentation/pages/clone_management_preview_page.dart';

Future<void> tapText(WidgetTester tester, String label) async {
  final finder = label == '删除当前模型克隆音色'
      ? find.byTooltip(label)
      : find.text(label);
  await tester.ensureVisible(finder.last);
  await tester.tap(finder.last);
  await tester.pumpAndSettle();
}

Future<void> openModel(WidgetTester tester, int index) async {
  final entry = find.byKey(
    ValueKey(
      index == 0 ? 'voices-QWEN_OMNI_PLUS' : 'voices-DOUBAO_SEEDUPLEX_3_0',
    ),
  );
  await tester.ensureVisible(entry);
  await tester.tap(entry);
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('delete confirmation, cancel and model isolation at $width', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 780);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: CloneManagementPreviewPage()),
        ),
      );
      await tester.pumpAndSettle();
      await openModel(tester, 0);
      await tapText(tester, '删除当前模型克隆音色');
      expect(find.text('删除 QwenOmniPlus 克隆音色？'), findsOneWidget);
      await tapText(tester, '取消');
      expect(
        tester
            .widget<NativeVoiceSelectionRow>(
              find.byKey(const ValueKey('selectCloneVoice')),
            )
            .selected,
        isTrue,
      );
      await tapText(tester, '删除当前模型克隆音色');
      await tapText(tester, '确认删除');
      expect(find.text('当前模型暂无可用的克隆音色，完成声音克隆后即可使用'), findsOneWidget);
      expect(find.byTooltip('删除当前模型克隆音色'), findsNothing);
      await tester.tap(find.byTooltip('关闭音色选择'));
      await tester.pumpAndSettle();
      await openModel(tester, 1);
      expect(
        tester
            .widget<NativeVoiceSelectionRow>(
              find.byKey(const ValueKey('selectCloneVoice')),
            )
            .selected,
        isTrue,
      );
      await tapText(tester, '删除当前模型克隆音色');
      expect(find.text('删除 Seeduplex V3 克隆音色？'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<NativeVoiceSelectionRow>(
              find.byKey(const ValueKey('selectCloneVoice')),
            )
            .selected,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('successful delete and failed read exposes sync and recovers', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: CloneManagementPreviewPage(failReadAfterDelete: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await openModel(tester, 0);
    await tapText(tester, '删除当前模型克隆音色');
    await tapText(tester, '确认删除');
    expect(find.text('等待同步'), findsOneWidget);
    await tapText(tester, '同步状态');
    expect(find.text('当前模型暂无可用的克隆音色，完成声音克隆后即可使用'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
