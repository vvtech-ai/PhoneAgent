import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/attachments/domain/ocr_attachment.dart';
import 'package:phone_agent/features/attachments/presentation/controller/ocr_controller.dart';

class _Port implements OcrRecognizer, OcrCommitter {
  int recognitions = 0, commits = 0;
  OcrRecognition recognition = const OcrRecognition('raw', ['raw']);
  Completer<OcrRecognition>? recognitionGate;
  Completer<OcrContent>? commitGate;
  bool recognitionError = false;
  OcrFailure? commitError;
  @override
  Future<OcrRecognition> recognize(String imageRef) async {
    recognitions++;
    if (recognitionError) throw StateError('private text');
    return recognitionGate?.future ?? recognition;
  }

  @override
  Future<OcrContent> commit(
    OcrAttachment attachment,
    OcrRecognition recognition,
  ) async {
    commits++;
    if (commitError != null) throw OcrCommitFailure(commitError!);
    return commitGate?.future ??
        OcrContent(fullText: '合成文字', fields: const [OcrField('姓名', '合成')]);
  }
}

void main() {
  late _Port port;
  late OcrController controller;
  setUp(() {
    port = _Port();
    var id = 0;
    controller = OcrController(port, port, () => 'ocr-${++id}');
  });
  tearDown(() {
    if (controller.mounted) controller.dispose();
  });
  test(
    'successful selections preserve boundary, ordinal and successful context',
    () async {
      await controller.select('one', -1);
      await controller.select('two', 7);
      expect(controller.snapshot.attachments.map((a) => a.anchor), [0, 7]);
      expect(controller.snapshot.attachments.map((a) => a.ordinal), [0, 1]);
      expect(controller.snapshot.successful, hasLength(2));
      expect(controller.snapshot.busy, false);
    },
  );
  test('single flight until recognition and commit complete', () async {
    port.commitGate = Completer();
    final first = controller.select('one', 2);
    await Future<void>.delayed(Duration.zero);
    await controller.select('two', 5);
    expect(port.recognitions, 1);
    expect(controller.snapshot.busy, true);
    port.commitGate!.complete(OcrContent(fullText: 'success'));
    await first;
    expect(controller.snapshot.attachments.single.anchor, 2);
  });
  test('empty recognition never commits or enters context', () async {
    port.recognition = const OcrRecognition('  ', []);
    await controller.select('one', 0);
    expect(port.commits, 0);
    expect(controller.snapshot.successful, isEmpty);
    expect(
      controller.snapshot.attachments.single.failure,
      OcrFailure.emptyText,
    );
  });
  test(
    'recognition error is redacted and explicit new selection works',
    () async {
      port.recognitionError = true;
      await controller.select('one', 0);
      expect(
        controller.snapshot.attachments.single.failureMessage,
        '图片文字识别失败，请重新选择图片',
      );
      port.recognitionError = false;
      await controller.select('two', 0);
      expect(controller.snapshot.attachments, hasLength(2));
      expect(controller.snapshot.successful, hasLength(1));
    },
  );
  for (final failure in [OcrFailure.refinement, OcrFailure.cloudCommit]) {
    test(
      'commit $failure never enters successful context or auto retries',
      () async {
        port.commitError = failure;
        await controller.select('one', 0);
        expect(controller.snapshot.attachments.single.failure, failure);
        expect(controller.snapshot.successful, isEmpty);
        expect(port.commits, 1);
      },
    );
  }
  for (final phase in ['recognition', 'commit']) {
    test('dispose during $phase discards late completion', () async {
      if (phase == 'recognition') {
        port.recognitionGate = Completer();
      } else {
        port.commitGate = Completer();
      }
      final pending = controller.select('one', 0);
      await Future<void>.delayed(Duration.zero);
      controller.dispose();
      port.recognitionGate?.complete(port.recognition);
      port.commitGate?.complete(OcrContent(fullText: 'late'));
      await pending;
      await controller.select('two', 0);
      expect(port.commits, phase == 'commit' ? 1 : 0);
      expect(port.recognitions, 1);
    });
  }
  test('v65 50 UTF16 chars cutoff and distinct first three field labels', () {
    final exact = OcrContent(fullText: '字' * 50);
    expect(exact.collapsible, false);
    final longer = OcrContent(
      fullText: '${exact.fullText}最后',
      fields: const [
        OcrField('姓名', 'a'),
        OcrField('姓名', 'b'),
        OcrField('电话', 'c'),
        OcrField('机构', 'd'),
        OcrField('地址', 'e'),
      ],
    );
    expect(longer.displayText(false), '${exact.fullText}……');
    expect(longer.displayText(true), endsWith('最后'));
    expect(longer.summary, '已从图片中提取姓名、电话、机构等信息');
  });
}
