import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/attachments/domain/ocr_attachment.dart';
import 'package:phone_agent/features/attachments/domain/ocr_image_source.dart';
import 'package:phone_agent/features/attachments/domain/ocr_persistence.dart';
import 'package:phone_agent/features/attachments/presentation/controller/ocr_session_controller.dart';

void main() {
  late _Ports ports;
  late OcrSessionController controller;
  var current = true, nextId = 0;
  setUp(() {
    ports = _Ports();
    current = true;
    nextId = 0;
    controller = OcrSessionController(
      sessionId: 'session',
      source: ports,
      recognizer: ports,
      repository: ports,
      nextId: () => '${++nextId}',
      isCurrent: () => current,
      initialOpening: () => '合成开场',
    );
  });
  tearDown(() => controller.dispose());

  test(
    'selection, local recognition and persistence produce shared context',
    () async {
      await controller.pick(3);
      expect(ports.uploads.single.attachment.anchor, 3);
      expect(ports.uploads.single.attachment.id, 'ocr-1');
      expect(ports.uploads.single.initialOpening, '合成开场');
      expect(
        controller.snapshot.processing.attachments.single.status,
        OcrStatus.success,
      );
      expect(controller.snapshot.images['ocr-1'], [1, 2, 3]);
      final attachments = controller.userContext!['ocrAttachments'] as List;
      expect(attachments.single['fullText'], '已整理');
      expect(attachments.single['attachmentId'], 'ocr-1');
    },
  );
  test(
    'cancel selection creates no attachment, recognition or upload',
    () async {
      ports.selection = Future.value(null);
      await controller.pick(0);
      expect(controller.snapshot.processing.attachments, isEmpty);
      expect(controller.snapshot.notice, isEmpty);
      expect(ports.recognitions, 0);
      expect(ports.uploads, isEmpty);
    },
  );
  test('picker is single flight', () async {
    final pending = Completer<SelectedOcrImage?>();
    ports.selection = pending.future;
    final first = controller.pick(2);
    await controller.pick(9);
    expect(ports.picks, 1);
    expect(controller.snapshot.busy, true);
    pending.complete(_image());
    await first;
    expect(ports.uploads.single.attachment.anchor, 2);
  });
  test('anchor is captured when selection returns, before image IO', () async {
    final selected = Completer<SelectedOcrImage?>();
    final bytes = Completer<Uint8List>();
    ports.selection = selected.future;
    var anchor = 2;
    final work = controller.pick(2, currentAnchor: () => anchor);
    anchor = 4;
    selected.complete(_image(read: () => bytes.future));
    await Future<void>.delayed(Duration.zero);
    anchor = 7;
    bytes.complete(Uint8List(3));
    await work;
    expect(ports.uploads.single.attachment.anchor, 4);
  });
  test('history reads are serial and closing skips the queued image', () async {
    final pending = Completer<Uint8List>();
    ports.imageResult = pending.future;
    controller.synchronize([
      _persisted('ocr-first'),
      _persisted('ocr-second', ordinal: 1),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(ports.imageLoads, 1);
    controller.close();
    pending.complete(Uint8List(3));
    await Future<void>.delayed(Duration.zero);
    expect(ports.imageLoads, 1);
    expect(controller.snapshot.images, isEmpty);
    expect(controller.userContext, isNull);
  });
  test(
    'closing during picker prevents reading and keeps state empty',
    () async {
      final pending = Completer<SelectedOcrImage?>();
      ports.selection = pending.future;
      var reads = 0;
      final work = controller.pick(0);
      controller.close();
      pending.complete(
        _image(
          read: () async {
            reads++;
            return Uint8List(3);
          },
        ),
      );
      await work;
      expect(reads, 0);
      expect(controller.snapshot.images, isEmpty);
      expect(controller.userContext, isNull);
    },
  );
  test('account lease changes during recognition prevent upload', () async {
    final pending = Completer<OcrRecognition>();
    ports.recognition = pending.future;
    final work = controller.pick(0);
    await Future<void>.delayed(Duration.zero);
    current = false;
    pending.complete(const OcrRecognition('text', ['text']));
    await work;
    expect(ports.uploads, isEmpty);
    expect(controller.userContext, isNull);
  });
  test('closing during upload discards response and context', () async {
    final pending = Completer<OcrCommitReceipt>();
    ports.uploadResult = pending.future;
    final work = controller.pick(0);
    await Future<void>.delayed(Duration.zero);
    expect(ports.uploads, hasLength(1));
    controller.close();
    pending.complete(OcrCommitReceipt(_persisted('ocr-1'), 'event', 1));
    await work;
    expect(controller.snapshot.processing.attachments, isEmpty);
    expect(controller.snapshot.images, isEmpty);
    expect(controller.userContext, isNull);
  });
  test('empty recognition does not upload or contribute context', () async {
    ports.recognition = Future.value(const OcrRecognition('  ', []));
    await controller.pick(0);
    expect(ports.uploads, isEmpty);
    expect(
      controller.snapshot.processing.attachments.single.failure,
      OcrFailure.emptyText,
    );
    expect(controller.userContext, isNull);
  });
  test('save failure preserves image but not usable context', () async {
    ports.failUpload = true;
    await controller.pick(0);
    expect(
      controller.snapshot.processing.attachments.single.failure,
      OcrFailure.refinement,
    );
    expect(controller.snapshot.images, hasLength(1));
    expect(controller.userContext, isNull);
  });
  test(
    'history is session scoped, keeps source anchor and advances ordinal',
    () async {
      controller.synchronize([
        _persisted('ocr-history', anchor: 8, ordinal: 4),
        _persisted('ocr-other', session: 'other'),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(controller.snapshot.processing.attachments.single.anchor, 8);
      expect(controller.snapshot.images.keys, ['ocr-history']);
      await controller.pick(9);
      expect(ports.uploads.single.attachment.ordinal, 5);
      expect(controller.userContext!['ocrAttachments'], hasLength(2));
    },
  );
  test(
    'v65 history image failure does not publish a successful attachment or context',
    () async {
      ports.failImage = true;
      final history = [_persisted('ocr-history')];
      controller.synchronize(history);
      await Future<void>.delayed(Duration.zero);
      controller.synchronize(history);
      await Future<void>.delayed(Duration.zero);
      expect(ports.imageLoads, 1);
      expect(controller.userContext, isNull);
      expect(controller.snapshot.processing.attachments, isEmpty);
      ports.failImage = false;
      await controller.retryImage('ocr-history');
      expect(ports.imageLoads, 2);
      expect(controller.snapshot.images.keys, ['ocr-history']);
      expect(controller.userContext!['ocrAttachments'], hasLength(1));
    },
  );
  test('late history image cannot repopulate a closed page', () async {
    final pending = Completer<Uint8List>();
    ports.imageResult = pending.future;
    controller.synchronize([_persisted('ocr-history')]);
    controller.close();
    pending.complete(Uint8List(3));
    await Future<void>.delayed(Duration.zero);
    expect(controller.snapshot.images, isEmpty);
  });
  test('durable success wins over a late local recognition failure', () async {
    final pending = Completer<OcrRecognition>();
    ports.recognition = pending.future;
    final work = controller.pick(2);
    await Future<void>.delayed(Duration.zero);
    controller.synchronize([_persisted('ocr-1', anchor: 99, ordinal: 7)]);
    pending.completeError(StateError('late failure'));
    await work;
    final item = controller.snapshot.processing.attachments.single;
    expect(item.status, OcrStatus.success);
    expect(item.anchor, 2);
    expect(item.ordinal, 7);
    expect(item.imageRef, '/synthetic.png');
    expect(ports.uploads, isEmpty);
  });
}

SelectedOcrImage _image({Future<Uint8List> Function()? read}) =>
    SelectedOcrImage(
      path: '/synthetic.png',
      name: 'synthetic.png',
      mimeType: 'image/png',
      size: 3,
      read: read ?? () async => Uint8List.fromList([1, 2, 3]),
    );
PersistedOcrAttachment _persisted(
  String id, {
  String session = 'session',
  int anchor = 0,
  int ordinal = 0,
}) => PersistedOcrAttachment(
  sessionId: session,
  id: id,
  contentType: 'image/png',
  fileSize: 3,
  anchor: anchor,
  ordinal: ordinal,
  content: OcrContent(fullText: '已整理'),
);

class _Ports implements OcrImageSource, OcrRecognizer, OcrAttachmentRepository {
  Future<SelectedOcrImage?>? selection;
  Future<OcrRecognition>? recognition;
  Future<OcrCommitReceipt>? uploadResult;
  Future<Uint8List>? imageResult;
  bool failUpload = false, failImage = false;
  int picks = 0, recognitions = 0, imageLoads = 0;
  final uploads = <OcrUpload>[];
  @override
  Future<SelectedOcrImage?> pick() {
    picks++;
    return selection ?? Future.value(_image());
  }

  @override
  Future<OcrRecognition> recognize(String imageRef) {
    recognitions++;
    return recognition ?? Future.value(const OcrRecognition('合成原文', ['合成原文']));
  }

  @override
  Future<OcrCommitReceipt> upload(OcrUpload input) async {
    uploads.add(input);
    if (failUpload) throw const OcrCommitFailure(OcrFailure.refinement);
    return uploadResult ??
        OcrCommitReceipt(
          _persisted(
            input.attachment.id,
            anchor: input.attachment.anchor,
            ordinal: input.attachment.ordinal,
          ),
          'event',
          1,
        );
  }

  @override
  Future<Uint8List> loadImage(PersistedOcrAttachment attachment) async {
    imageLoads++;
    if (failImage) throw StateError('offline');
    return imageResult ?? Uint8List(3);
  }
}
