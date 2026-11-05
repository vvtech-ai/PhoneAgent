import '../../support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/attachments/data/preview_ocr_session.dart';
import 'package:phone_agent/features/attachments/domain/document_import.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_page.dart';
import '../attachments/ocr_conversation_flow_test.dart' show createConversation;

class _DocumentPorts extends PreviewOcrSession {
  @override
  AgentRun start(AgentCommand command) {
    if (events.isEmpty && command.initialOpening != null) {
      events.add(
        LedgerEvent(
          eventId: 'opening',
          sessionId: PreviewOcrSession.sessionId,
          sequence: 1,
          type: 'ASSISTANT_TURN_COMMITTED',
          schemaVersion: 1,
          commandId: 'initial-opening:${PreviewOcrSession.sessionId}',
          payload: {'text': command.initialOpening!},
        ),
      );
    }
    commands.add(command);
    Stream<AgentEvent> reply() async* {
      final user = _append('USER_TURN_ACCEPTED', {
        'text': command.message!,
        'inputKind': command.inputKind!,
      }, command.commandId);
      yield AgentEvent(AgentEventKind.committed, ledger: user);
      final answer = _append('ASSISTANT_TURN_COMMITTED', {
        'text': '已收到文档，继续补充任务信息。',
      }, command.commandId);
      yield AgentEvent(AgentEventKind.committed, ledger: answer);
      yield const AgentEvent(AgentEventKind.done);
    }

    return AgentRun(reply(), () {});
  }

  LedgerEvent _append(
    String type,
    Map<String, Object?> payload,
    String command,
  ) {
    final event = LedgerEvent(
      eventId: 'fact-${events.length + 1}',
      sessionId: PreviewOcrSession.sessionId,
      sequence: events.length + 1,
      type: type,
      schemaVersion: 1,
      commandId: command,
      payload: payload,
    );
    events.add(event);
    return event;
  }
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final extension in ['docx', 'xlsx']) {
      testWidgets(
        '$platform first $extension then cold restore retains opening and document order',
        (tester) async {
          tester.view.physicalSize = const Size(430, 1500);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final ports = _DocumentPorts();
          final original = createConversation(ports);
          final turn = DocumentTurn('first-document', [
            ParsedDocument(
              status: 'OK',
              fileName: '合成资料.$extension',
              charCount: 12,
              content: '合成正文',
            ),
          ]);
          expect(original.sendDocument(turn), isTrue);
          for (var i = 0; i < 5; i++) {
            await tester.pump();
          }
          expect(ports.commands.single.initialOpening, '合成开场');
          expect(ports.commands.single.inputKind, 'document');
          original.dispose();
          final restored = createConversation(ports);
          addTearDown(restored.dispose);
          await restored.restore();
          for (var i = 0; i < 5; i++) {
            await tester.pump();
          }
          final messages = restored.state.messages;
          expect(messages.first.text, '合成开场');
          expect(messages.where((m) => m.document != null), hasLength(1));
          expect(messages[1].document!.files.single.name, '合成资料.$extension');
          expect(restored.ocrBoundary.displayBoundaryFor(0), 1);
          expect(restored.ocrBoundary.displayBoundaryFor(2), 2);
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Scaffold(
                body: ConversationPage(
                  state: restored.state,
                  modelName: '模型',
                  onClose: () {},
                  onToggle: () {},
                  onSend: (_) => false,
                  onChoose: (_, _) => false,
                  onRetry: () {},
                  onNotice: (_) {},
                  onModels: () {},
                ),
              ),
            ),
          );
          await tester.pumpUntilUiSettled();
          expect(find.text('合成开场'), findsOneWidget);
          expect(
            tester.getTopLeft(find.text('合成开场')).dy,
            lessThan(tester.getTopLeft(find.text('已上传任务资料')).dy),
          );
          expect(
            tester.getTopLeft(find.text('已上传任务资料')).dy,
            lessThan(tester.getTopLeft(find.text('已收到文档，继续补充任务信息。')).dy),
          );
          expect(find.textContaining('user_document_batch.v1'), findsNothing);
          expect(ports.commands, hasLength(1));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
