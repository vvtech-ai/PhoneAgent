import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/attachments/data/preview_ocr_session.dart';
import 'package:phone_agent/features/attachments/presentation/controller/ocr_session_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'photo before first message keeps skill/contact and sends actual OCR context',
    () async {
      final ports = PreviewOcrSession();
      final controller = createConversation(ports);
      addTearDown(controller.dispose);
      await controller.attachments!.pick(controller.ocrBoundary.sourceAnchor);
      expect(ports.commands, isEmpty);
      expect(controller.send('整理图片，不要拨号'), true);
      await flush();
      final command = ports.commands.single;
      expect(command.initialSkillId, 'restaurant_booking');
      expect(command.selectedContact?.name, '合成联系人');
      expect(command.userContext!['ocrAttachments'], hasLength(1));
      expect(command.toJson()['channel'], 'voice');
      expect(controller.ocrBoundary.sourceAnchor, 2);
      expect(controller.send('继续'), true);
      await flush();
      expect(ports.commands.last.initialSkillId, isNull);
      expect(ports.commands.last.userContext!['ocrAttachments'], hasLength(1));
    },
  );
  test(
    'close then restore reconstructs image, source anchor and context without upload',
    () async {
      final ports = PreviewOcrSession();
      final original = createConversation(ports);
      original.send('合成第一轮');
      await flush();
      await original.attachments!.pick(original.ocrBoundary.sourceAnchor);
      original.send('合成第二轮');
      await flush();
      final before = ports.events.length;
      original.dispose();
      final restored = createConversation(ports);
      addTearDown(restored.dispose);
      await restored.restore();
      await flush();
      final image =
          restored.attachments!.snapshot.processing.attachments.single;
      expect(image.anchor, 2);
      expect(restored.ocrBoundary.displayBoundaryFor(image.anchor), 2);
      expect(restored.attachments!.snapshot.images.keys, contains(image.id));
      expect(ports.events.length, before);
      expect(restored.send('历史继续'), true);
      await flush();
      expect(ports.commands.last.userContext!['ocrAttachments'], hasLength(1));
    },
  );
}

ConversationController createConversation(PreviewOcrSession ports) {
  late final ConversationController controller;
  var id = 0;
  final ocr = OcrSessionController(
    sessionId: PreviewOcrSession.sessionId,
    source: ports,
    recognizer: ports,
    repository: ports,
    nextId: () => 'synthetic-${++id}',
    isCurrent: () => controller.isOpen,
    initialOpening: () => controller.pendingInitialOpening,
  );
  controller = ConversationController(
    entry: const ConversationEntry(
      sessionId: PreviewOcrSession.sessionId,
      skillId: 'restaurant_booking',
      opening: '合成开场',
      selectedContact: SelectedContactContext(
        name: '合成联系人',
        phone: '+15555550100',
      ),
    ),
    accountId: 'synthetic',
    gateway: ports,
    history: ports,
    attachments: ocr,
    nextId: () => 'command-${++id}',
  );
  return controller;
}

Future<void> flush() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
