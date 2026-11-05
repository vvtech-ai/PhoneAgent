import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/attachments/data/preview_ocr.dart';
import 'package:phone_agent/features/attachments/domain/ocr_attachment.dart';
import 'package:phone_agent/features/attachments/domain/ocr_persistence.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';
import '../tool/previews/shell_attachment_ports.dart';
import '../tool/previews/shell_conversation_ports.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('adding OCR to a seed task retains its original history', () async {
    final conversations = ShellConversationPorts();
    final original = await conversations.restore('closed');
    final event = await conversations.commitOcr('closed', {'synthetic': true});
    final restored = await conversations.restore('closed');
    expect(
      restored.ledger!.events
          .take(original.ledger!.head)
          .map((e) => e.fingerprint),
      original.ledger!.events.map((e) => e.fingerprint),
    );
    expect(event.sequence, original.ledger!.head + 1);
    expect(restored.detail.title, original.detail.title);
    conversations.close();
  });

  test('image-only task restores immutable bytes by session and ID', () async {
    final conversations = ShellConversationPorts();
    final ports = ShellAttachmentPorts(conversations);
    final upload = await input(ports);
    final receipt = await ports.upload(upload);
    final snapshot = await conversations.restore('a');
    expect(snapshot.ledger!.events.single.type, 'OCR_IMAGE_COMMITTED');
    expect(snapshot.ledger!.events.single.sequence, receipt.sequence);
    final restored = PersistedOcrAttachment.fromPayload(
      'a',
      snapshot.ledger!.events.single.payload,
    );
    final bytes = await ports.loadImage(restored);
    bytes[0] = 0;
    expect((await ports.loadImage(restored))[0], upload.bytes[0]);
    expect(conversations.commands, isEmpty);
    final tasks = await conversations.load(TaskSource.conversations);
    expect(tasks.singleWhere((t) => t.sessionId == 'a').title, 'MOCK · 图片资料');
    final foreign = PersistedOcrAttachment(
      sessionId: 'b',
      id: restored.id,
      contentType: restored.contentType,
      fileSize: restored.fileSize,
      anchor: restored.anchor,
      ordinal: restored.ordinal,
      content: restored.content,
    );
    await expectLater(ports.loadImage(foreign), throwsStateError);
    ports.close();
    await expectLater(ports.loadImage(restored), throwsStateError);
    conversations.close();
  });

  test('failed OCR commit does not create a task or usable history', () async {
    final conversations = ShellConversationPorts();
    final ports = ShellAttachmentPorts(conversations)
      ..imageScenario = OcrPreviewScenario.cloudCommit;
    await expectLater(
      ports.upload(await input(ports)),
      throwsA(isA<OcrCommitFailure>()),
    );
    expect(ports.uploads, 0);
    expect(
      (await conversations.load(
        TaskSource.conversations,
      )).any((t) => t.sessionId == 'a'),
      false,
    );
    ports.close();
    conversations.close();
  });

  test(
    'scope disposal rejects late upload before adding any ledger fact',
    () async {
      for (final closeConversation in [false, true]) {
        final conversations = ShellConversationPorts();
        final ports = ShellAttachmentPorts(conversations);
        final pending = ports.upload(await input(ports));
        if (closeConversation) {
          conversations.close();
        } else {
          ports.close();
        }
        await expectLater(pending, throwsStateError);
        expect(ports.uploads, 0);
        expect(
          (await conversations.load(
            TaskSource.conversations,
          )).any((t) => t.sessionId == 'a'),
          false,
        );
        ports.close();
        conversations.close();
      }
    },
  );
}

Future<OcrUpload> input(ShellAttachmentPorts ports) async {
  final image = await ports.pickImage();
  return OcrUpload(
    sessionId: 'a',
    attachment: OcrAttachment(
      id: 'ocr-one',
      imageRef: image.path,
      anchor: 0,
      ordinal: 0,
    ),
    bytes: await image.read(),
    fileName: image.name,
    mimeType: image.mimeType,
    recognition: const OcrRecognition('合成文字', ['合成文字']),
  );
}
