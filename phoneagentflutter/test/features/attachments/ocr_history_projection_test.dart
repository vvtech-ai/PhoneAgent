import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/attachments/domain/ocr_history_projection.dart';
import 'package:phone_agent/features/attachments/domain/ocr_persistence.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'ocr_test_support.dart';

void main() {
  LedgerEvent fact(
    int sequence,
    Map<String, Object?> payload, {
    String session = ocrTestSession,
    int schema = 1,
    String type = 'OCR_IMAGE_COMMITTED',
  }) => LedgerEvent(
    eventId: 'event-$sequence',
    sessionId: session,
    sequence: sequence,
    type: type,
    schemaVersion: schema,
    payload: payload,
  );
  test(
    'latest valid attachment identity and original selection order/anchor',
    () {
      final items = OcrHistoryProjection.project(ocrTestSession, [
        fact(10, ocrPayload(id: 'ocr-second', anchor: 9, ordinal: 2)),
        fact(30, {
          ...ocrPayload(id: 'ocr-first', anchor: 1, ordinal: 1),
          'fullText': 'latest',
        }),
        fact(2, ocrPayload(id: 'ocr-first', anchor: 1, ordinal: 1)),
      ]);
      expect(items.map((e) => e.id), ['ocr-first', 'ocr-second']);
      expect(items.first.anchor, 1);
      expect(items.first.content.fullText, 'latest');
      expect(items.last.anchor, 9);
      expect(items.first.context['attachmentId'], 'ocr-first');
      expect(items.first.context.keys, [
        'attachmentId',
        'fields',
        'segments',
        'fullText',
      ]);
    },
  );
  test(
    'unknown schema, foreign session and malformed records are not success',
    () {
      final items = OcrHistoryProjection.project(ocrTestSession, [
        fact(1, ocrPayload()),
        fact(2, ocrPayload(), schema: 2),
        fact(3, ocrPayload(id: 'ocr-foreign'), session: 'other'),
        fact(4, {...ocrPayload(), 'fullText': ''}),
        fact(
          5,
          ocrPayload(id: 'ocr-not-image'),
          type: 'ASSISTANT_TURN_COMMITTED',
        ),
      ]);
      expect(items.length, 1);
      expect(items.single.content.fullText, '合成图片文字');
    },
  );
  test(
    'server contentPath cannot redirect image request or expose credentials',
    () {
      final item = PersistedOcrAttachment.fromPayload(ocrTestSession, {
        ...ocrPayload(),
        'contentPath': 'https://untrusted.test/image?token=not-used',
      });
      expect(
        item.path,
        'api/agent/conversations/$ocrTestSession/attachments/$ocrTestId/content',
      );
      expect(item.display('memory-image').imageRef, 'memory-image');
      expect(item.display('memory-image').anchor, 2);
    },
  );
  test('invalid media, counts, field types and path IDs rejected', () {
    for (final change in <Map<String, Object?>>[
      {'attachmentId': 'ocr-../bad'},
      {'contentType': 'text/html'},
      {'fileSize': 0},
      {'fileSize': ocrMaxImageBytes + 1},
      {'anchorStepCount': -1},
      {'createdOrdinal': -1},
      {'fields': 'wrong'},
      {
        'segments': [3],
      },
      {'contentPath': ''},
    ]) {
      expect(
        () => PersistedOcrAttachment.fromPayload(ocrTestSession, {
          ...ocrPayload(),
          ...change,
        }),
        throwsFormatException,
      );
    }
  });
}
