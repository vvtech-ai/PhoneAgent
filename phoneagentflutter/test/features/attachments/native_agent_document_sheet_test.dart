import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/attachments/domain/agent_document_request.dart';
import 'package:phone_agent/features/attachments/domain/document_import.dart';
import 'package:phone_agent/features/attachments/presentation/controller/agent_document_controller.dart';
import 'package:phone_agent/features/attachments/presentation/widgets/agent_document_host.dart';
import 'package:phone_agent/features/attachments/presentation/widgets/native_agent_document_sheet.dart';

import 'agent_document_test.dart' show DocumentFake;

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'Agent file sheet short font busy cancel and late parse $platform',
      (tester) async {
        tester.view.physicalSize = const Size(320, 390);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final semantics = tester.ensureSemantics();
        final files = DocumentFake()
          ..pendingParse = Completer<ParsedDocument>();
        final controller = AgentDocumentController(files, files);
        addTearDown(controller.dispose);
        final result = controller.resolve(
          const AgentDocumentRequest(
            title: '上传合成会议名单',
            reason: '用于邀请参会人员并整理通知结果',
          ),
          isCurrent: () => true,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: AgentDocumentHost(
                controller: controller,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
        final pick = find.byKey(const ValueKey('agent-document-pick'));
        expect(find.byTooltip('取消文件选择'), findsNothing);
        expect(
          tester
              .getSemantics(find.bySemanticsLabel('点击选择文件，支持 Markdown、TXT'))
              .getSemanticsData()
              .hasAction(ui.SemanticsAction.tap),
          isTrue,
        );
        await tester.ensureVisible(pick);
        await tester.pump();
        await tester.tap(pick);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('正在解析文件'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(
          tester
              .getSemantics(find.bySemanticsLabel('正在解析文件，支持 Markdown、TXT'))
              .getSemanticsData()
              .hasAction(ui.SemanticsAction.tap),
          isFalse,
        );
        await tester.tap(pick);
        await tester.pump();
        expect(files.picks, 1);
        expect(files.parses, 1);
        expect(tester.takeException(), isNull);
        await tester.tapAt(const Offset(8, 8));
        await tester.pump();
        expect((await result)!.status, 'USER_CANCELLED');
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(NativeAgentDocumentSheet), findsNothing);
        files.pendingParse!.complete(const ParsedDocument(status: 'OK'));
        await tester.pumpAndSettle();
        expect(controller.snapshot, isNull);
        expect(tester.takeException(), isNull);
        semantics.dispose();
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
