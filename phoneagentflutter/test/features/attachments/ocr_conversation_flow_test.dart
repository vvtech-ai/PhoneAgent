import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/attachments/data/preview_ocr_session.dart';
import 'package:phone_agent/features/attachments/presentation/controller/ocr_session_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/attachments/domain/ocr_persistence.dart';

class _CaptureOcrSession extends PreviewOcrSession {
  final uploads = <OcrUpload>[];
  @override
  Future<OcrCommitReceipt> upload(OcrUpload input) {
    uploads.add(input);
    return super.upload(input);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final skill in [
    'business_event_invitation',
    'meeting_notification_v2',
    'future_skill',
  ]) {
    test('OCR upload preserves arbitrary entry Skill: $skill', () async {
      final ports = _CaptureOcrSession();
      final controller = createConversation(ports, skillId: skill);
      addTearDown(controller.dispose);
      await controller.attachments!.pick(0);
      expect(ports.uploads.single.initialSkillId, skill);
      expect(ports.uploads.single.selectedContact?.name, '合成联系人');
      expect(ports.commands, isEmpty);
      expect(controller.send('仅整理，不拨号'), true);
      await flush();
      await controller.attachments!.pick(controller.ocrBoundary.sourceAnchor);
      expect(ports.uploads.last.initialSkillId, isNull);
      expect(ports.uploads.last.selectedContact, isNull);
    });
  }
  test(
    'OCR-only restore still sends the original first task context',
    () async {
      final ports = PreviewOcrSession();
      final original = createConversation(ports);
      await original.attachments!.pick(0);
      original.dispose();
      final restored = createConversation(ports);
      addTearDown(restored.dispose);
      await restored.restore();
      await flush();
      expect(ports.commands, isEmpty);
      expect(restored.send('通知名单中的同事周五参加活动'), true);
      await flush();
      expect(ports.commands.single.initialSkillId, 'restaurant_booking');
      expect(ports.commands.single.selectedContact?.name, '合成联系人');
      expect(ports.commands.single.initialOpening, '合成开场');
      expect(restored.send('继续补充'), true);
      await flush();
      expect(ports.commands.last.initialSkillId, isNull);
    },
  );
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
      expect(ports.commands.last.initialSkillId, isNull);
      expect(ports.commands.last.selectedContact, isNull);
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

ConversationController createConversation(
  PreviewOcrSession ports, {
  String? skillId = 'restaurant_booking',
}) {
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
    initialSkillId: () => controller.pendingInitialEntry?.skillId,
    selectedContact: () => controller.pendingInitialEntry?.selectedContact,
  );
  controller = ConversationController(
    entry: ConversationEntry(
      sessionId: PreviewOcrSession.sessionId,
      skillId: skillId,
      opening: '合成开场',
      selectedContact: const SelectedContactContext(
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
