import '../../support/pump_ui_transitions.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/attachments/domain/document_import.dart';
import 'package:phone_agent/features/attachments/presentation/controller/agent_document_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import '../../../tool/previews/agent_document_preview_page.dart';
import '../../../tool/previews/agent_document_preview_ports.dart';
import 'agent_document_test.dart' show DocumentFake;

void main() {
  test(
    'real controller document continuation and ordinary text share session',
    () async {
      final ports = AgentDocumentPreviewPorts();
      final docs = AgentDocumentController(ports, ports);
      final controller = ConversationController(
        entry: const ConversationEntry(sessionId: 's'),
        accountId: 'u',
        gateway: ports,
        history: ports,
        documents: docs,
      );
      late ConversationState state;
      controller.addListener((value) => state = value);
      controller.send('请求文档');
      await Future<void>.delayed(Duration.zero);
      expect(docs.snapshot, isNotNull);
      await docs.choose();
      await Future<void>.delayed(Duration.zero);
      expect(ports.commands, hasLength(2));
      expect(ports.commands.last.actionId, 'submit_document');
      expect(state.canSend, true);
      expect(
        state.messages.where((m) => m.text.contains('已上传并解析')),
        hasLength(1),
      );
      expect(state.messages.any((m) => m.text.contains('mock content')), false);
      controller.send('继续');
      await Future<void>.delayed(Duration.zero);
      expect(ports.commands.every((c) => c.sessionId == 's'), true);
      expect(state.messages.any((m) => m.text == 'MOCK 继续对话成功。'), true);
      controller.dispose();
    },
  );
  for (final restore in [true, false]) {
    test(
      'live parse invalidated by ${restore ? 'restore' : 'close'} is never submitted',
      () async {
        final ports = AgentDocumentPreviewPorts();
        final files = DocumentFake()
          ..pendingParse = Completer<ParsedDocument>();
        final docs = AgentDocumentController(files, files);
        final controller = ConversationController(
          entry: const ConversationEntry(sessionId: 's'),
          accountId: 'u',
          gateway: ports,
          history: ports,
          documents: docs,
        );
        controller.send('请求文档');
        await Future<void>.delayed(Duration.zero);
        final choosing = docs.choose();
        await Future<void>.delayed(Duration.zero);
        if (restore) {
          await controller.restore();
        } else {
          controller.close();
        }
        files.pendingParse!.complete(const ParsedDocument(status: 'OK'));
        await choosing;
        await Future<void>.delayed(Duration.zero);
        expect(ports.commands, hasLength(1));
        expect(docs.snapshot, isNull);
        controller.dispose();
      },
    );
  }
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('document success/cancel/failure/oversize/continue at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(home: AgentDocumentPreviewPage()),
      );
      Future<void> trigger() async {
        await tester.tap(find.text('触发文档请求'));
        await tester.pumpUntilUiSettled();
        expect(
          find.byKey(const ValueKey('agent-document-pick')),
          findsOneWidget,
        );
      }

      await trigger();
      await tester.tap(find.byKey(const ValueKey('agent-document-pick')));
      await tester.pumpUntilUiSettled();
      expect(find.textContaining('MOCK 已收到文档结果：OK'), findsOneWidget);
      await trigger();
      await tester.tapAt(
        tester.getRect(find.byType(ModalBarrier).last).topLeft +
            const Offset(8, 8),
      );
      await tester.pumpUntilUiSettled();
      expect(
        find.textContaining('MOCK 已收到文档结果：USER_CANCELLED'),
        findsOneWidget,
      );
      var selected = '解析成功';
      for (final pair in [
        ('解析失败', 'PARSE_FAILED'),
        ('文件超限', 'FILE_TOO_LARGE'),
      ]) {
        await tester.tap(find.text(selected));
        await tester.pumpUntilUiSettled();
        await tester.tap(find.text(pair.$1).last);
        await tester.pumpUntilUiSettled();
        selected = pair.$1;
        await trigger();
        await tester.tap(find.byKey(const ValueKey('agent-document-pick')));
        await tester.pumpUntilUiSettled();
        expect(find.textContaining('MOCK 已收到文档结果：${pair.$2}'), findsOneWidget);
      }
      await tester.tap(find.text('继续文字对话'));
      await tester.pumpUntilUiSettled();
      expect(find.text('MOCK 继续对话成功。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
