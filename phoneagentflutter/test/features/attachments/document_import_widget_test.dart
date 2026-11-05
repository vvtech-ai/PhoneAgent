import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/attachments/data/preview_documents.dart';
import 'package:phone_agent/features/attachments/presentation/controller/document_import_controller.dart';
import 'package:phone_agent/features/attachments/presentation/widgets/attachment_menu.dart';
import 'package:phone_agent/features/attachments/presentation/widgets/document_import_sheet.dart';

void main() {
  Future<void> open(
    WidgetTester tester,
    DocumentPreviewScenario scenario, {
    bool preview = true,
    bool accepted = true,
    VoidCallback? submitted,
  }) async {
    final port = PreviewDocuments(scenario);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => DocumentImportSheet(
                  controller: DocumentImportController(
                    port,
                    port,
                    () => 'batch',
                  ),
                  preview: preview,
                  onReady: (_) {
                    submitted?.call();
                    return accepted;
                  },
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('pick-documents')));
    await tester.pump();
    // Two sequential synthetic parser calls.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('menu and multi-file success fit portrait width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AttachmentChoice? choice;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttachmentMenu(
              onChoose: (value) => choice = value,
              onClose: () {},
            ),
          ),
        ),
      );
      await tester.tap(find.text('文档'));
      expect(choice, AttachmentChoice.document);
      expect(find.textContaining('MOCK'), findsNothing);
      expect(tester.takeException(), isNull);
      var submissions = 0;
      await open(
        tester,
        DocumentPreviewScenario.success,
        submitted: () => submissions++,
      );
      await choose(tester);
      expect(find.byKey(const ValueKey('document-summary')), findsOneWidget);
      expect(find.textContaining('未提交真实 Agent'), findsOneWidget);
      expect(submissions, 0);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('关闭文档导入'));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
    });
  }
  testWidgets('partial parse failure exposes reselect, never submits', (
    tester,
  ) async {
    var submissions = 0;
    await open(
      tester,
      DocumentPreviewScenario.failure,
      preview: false,
      submitted: () => submissions++,
    );
    await choose(tester);
    expect(find.text('重新选择文件'), findsOneWidget);
    expect(find.text('MOCK：第二个文件解析失败'), findsOneWidget);
    expect(submissions, 0);
  });
  testWidgets('picker cancellation closes without sending', (tester) async {
    var submissions = 0;
    await open(
      tester,
      DocumentPreviewScenario.cancelled,
      preview: false,
      submitted: () => submissions++,
    );
    await choose(tester);
    expect(find.byType(DocumentImportSheet), findsNothing);
    expect(submissions, 0);
  });
  testWidgets('normal successful import submits exactly once and closes', (
    tester,
  ) async {
    var submissions = 0;
    await open(
      tester,
      DocumentPreviewScenario.success,
      preview: false,
      submitted: () => submissions++,
    );
    await choose(tester);
    expect(submissions, 1);
    expect(find.byType(DocumentImportSheet), findsNothing);
  });
  testWidgets(
    'changed conversation rejects send with visible local explanation',
    (tester) async {
      await open(
        tester,
        DocumentPreviewScenario.success,
        preview: false,
        accepted: false,
      );
      await choose(tester);
      expect(find.textContaining('文档未发送'), findsOneWidget);
      expect(find.byType(DocumentImportSheet), findsOneWidget);
    },
  );
  testWidgets('closing during parse drops result, reopening gets fresh state', (
    tester,
  ) async {
    var submissions = 0;
    await open(
      tester,
      DocumentPreviewScenario.success,
      preview: false,
      submitted: () => submissions++,
    );
    await tester.tap(find.byKey(const ValueKey('pick-documents')));
    await tester.pump();
    await tester.tap(find.byTooltip('关闭文档导入'));
    await tester.pumpAndSettle();
    expect(submissions, 0);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pick-documents')), findsOneWidget);
    expect(find.byKey(const ValueKey('document-summary')), findsNothing);
  });
}
