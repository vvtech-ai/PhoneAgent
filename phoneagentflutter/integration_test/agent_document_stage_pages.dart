import '../test/support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../tool/previews/migration_workbench.dart';
import '../tool/previews/workbench_catalog.dart';

Future<void> verifyAgentDocumentStage(
  WidgetTester tester, {
  required Future<void> Function(String) capture,
}) async {
  await tester.pumpWidget(
    MigrationWorkbench(
      key: const ValueKey('document-stage'),
      scenes: [workbenchScenes.singleWhere((s) => s.id == 'agent-document')],
    ),
  );
  await tester.pumpUntilUiSettled();
  Future<void> tap(Finder target) async {
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpUntilUiSettled();
    expect(tester.takeException(), isNull);
  }

  await tap(find.byKey(const ValueKey('scene-agent-document')));
  await tap(find.text('触发文档请求'));
  expect(find.text('上传文档'), findsOneWidget);
  await capture('59-agent-document-request');
  await tap(find.byKey(const ValueKey('agent-document-pick')));
  expect(find.textContaining('MOCK 已收到文档结果：OK'), findsOneWidget);
  expect(find.text('已上传并解析：演练资料.md'), findsOneWidget);
  await capture('60-agent-document-success');
  await tap(find.text('触发文档请求'));
  // Tap inside the actual nested overlay, outside the bottom sheet.
  final barrier = find.byType(ModalBarrier).last;
  await tester.tapAt(tester.getRect(barrier).topLeft + const Offset(8, 8));
  await tester.pumpUntilUiSettled();
  expect(tester.takeException(), isNull);
  expect(find.textContaining('MOCK 已收到文档结果：USER_CANCELLED'), findsOneWidget);
  await capture('61-agent-document-cancel');
  await tap(find.text('继续文字对话'));
  expect(find.text('MOCK 继续对话成功。'), findsOneWidget);
  await capture('62-agent-document-continue');
  await tap(find.byKey(const ValueKey('workbench-home')));
}
