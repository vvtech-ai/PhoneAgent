import '../../support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_ocr_boundary.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_page.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_timeline_attachment.dart';
import 'package:phone_agent/features/attachments/data/preview_ocr_session.dart';
import 'package:phone_agent/features/attachments/domain/ocr_persistence.dart';
import '../attachments/ocr_conversation_flow_test.dart'
    show createConversation, flush;

class _InitialUpload extends PreviewOcrSession {
  int uploads = 0;
  @override
  Future<OcrCommitReceipt> upload(OcrUpload input) async {
    uploads++;
    if (events.isEmpty && input.initialOpening != null) {
      events.add(
        LedgerEvent(
          eventId: 'initial',
          sessionId: PreviewOcrSession.sessionId,
          sequence: 1,
          type: 'ASSISTANT_TURN_COMMITTED',
          schemaVersion: 1,
          commandId: 'initial-opening:${PreviewOcrSession.sessionId}',
          payload: {'text': input.initialOpening!},
        ),
      );
    }
    return super.upload(input);
  }
}

LedgerEvent _fact(
  int sequence,
  String text, {
  String? command,
  int schema = 1,
}) => LedgerEvent(
  eventId: 'e$sequence',
  sessionId: 'synthetic',
  sequence: sequence,
  type: 'ASSISTANT_TURN_COMMITTED',
  schemaVersion: schema,
  commandId: command,
  payload: {'text': text},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'first OCR upload then cold restore preserves opening before stored zero anchor',
    () async {
      final ports = _InitialUpload();
      final first = createConversation(ports);
      expect(first.ocrBoundary.sourceAnchor, 0);
      await first.attachments!.pick(first.ocrBoundary.sourceAnchor);
      expect(
        first.attachments!.snapshot.processing.attachments.single.anchor,
        0,
      );
      first.dispose();
      final reopened = createConversation(ports);
      addTearDown(reopened.dispose);
      for (var i = 0; i < 2; i++) {
        await reopened.restore();
        await flush();
        final image =
            reopened.attachments!.snapshot.processing.attachments.single;
        expect(image.anchor, 0);
        expect(reopened.ocrBoundary.displayBoundaryFor(image.anchor), 1);
        expect(reopened.state.messages.first.text, '合成开场');
      }
      expect(ports.uploads, 1);
      expect(ports.events, hasLength(2));
      expect(ports.commands, isEmpty);
    },
  );
  test(
    'stored zero anchor stays after initial opening without shifting later steps',
    () {
      final facts = [
        _fact(1, '开场白', command: 'initial-opening:synthetic'),
        _fact(3, '后续回复'),
      ];
      final messages = ConversationMessages.project(facts);
      final boundary = ConversationOcrBoundary.project(facts, messages);
      expect(boundary.sourceAnchor, 2);
      expect(boundary.displayBoundaryFor(0), 1);
      expect(boundary.displayBoundaryFor(1), 1);
      expect(boundary.displayBoundaryFor(2), 2);
      expect(facts.first.payload['text'], '开场白');
    },
  );
  for (final command in [null, 'ordinary-command', 'initial-opening:other']) {
    test(
      'ordinary or foreign opening-like text retains zero boundary: $command',
      () {
        final facts = [_fact(1, '开场白', command: command)];
        expect(
          ConversationOcrBoundary.project(
            facts,
            ConversationMessages.project(facts),
          ).displayBoundaryFor(0),
          0,
        );
      },
    );
  }
  test(
    'unknown schema and non-leading initial identity do not move earlier content',
    () {
      final unknown = [
        _fact(1, '开场白', command: 'initial-opening:synthetic', schema: 9),
      ];
      expect(
        ConversationOcrBoundary.project(
          unknown,
          ConversationMessages.project(unknown),
        ).displayBoundaryFor(0),
        0,
      );
      final late = [
        _fact(1, '已有对话'),
        _fact(2, '迟到内容', command: 'initial-opening:synthetic'),
      ];
      expect(
        ConversationOcrBoundary.project(
          late,
          ConversationMessages.project(late),
        ).displayBoundaryFor(0),
        0,
      );
    },
  );

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform restored opening precedes first photos and later reply stays ordered',
      (tester) async {
        tester.view.physicalSize = const Size(430, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final facts = [
          _fact(1, '历史开场白', command: 'initial-opening:synthetic'),
          _fact(4, '后续回复'),
        ];
        final messages = ConversationMessages.project(facts);
        final boundary = ConversationOcrBoundary.project(facts, messages);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: ConversationPage(
                state: ConversationState(
                  entry: const ConversationEntry(
                    sessionId: 'synthetic',
                    restore: true,
                    opening: '历史开场白',
                  ),
                  messages: messages,
                ),
                modelName: '模型',
                onClose: () {},
                onToggle: () {},
                onSend: (_) => false,
                onChoose: (_, _) => false,
                onRetry: () {},
                onNotice: (_) {},
                onModels: () {},
                attachments: [
                  ConversationTimelineAttachment(
                    'first',
                    boundary.displayBoundaryFor(0),
                    const Text('图片一及识别卡'),
                  ),
                  ConversationTimelineAttachment(
                    'second',
                    boundary.displayBoundaryFor(0),
                    const Text('图片二及识别卡'),
                  ),
                  ConversationTimelineAttachment(
                    'later',
                    boundary.displayBoundaryFor(2),
                    const Text('后续图片'),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpUntilUiSettled();
        double top(String text) => tester.getTopLeft(find.text(text)).dy;
        expect(find.text('历史开场白'), findsOneWidget);
        expect(top('历史开场白'), lessThan(top('图片一及识别卡')));
        expect(top('图片一及识别卡'), lessThan(top('图片二及识别卡')));
        expect(top('图片二及识别卡'), lessThan(top('后续回复')));
        expect(top('后续回复'), lessThan(top('后续图片')));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
