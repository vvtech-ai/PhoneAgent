import '../../conversation/domain/history/ledger_event.dart';
import 'ocr_persistence.dart';

/// Durable facts determine content; selection anchor is never inferred from
/// commit order because recognition may finish after newer text turns.
abstract final class OcrHistoryProjection {
  static List<PersistedOcrAttachment> project(
    String sessionId,
    Iterable<LedgerEvent> facts,
  ) {
    final ordered =
        facts
            .where(
              (event) =>
                  event.sessionId == sessionId &&
                  event.schemaVersion == 1 &&
                  event.type == 'OCR_IMAGE_COMMITTED',
            )
            .toList()
          ..sort(
            (a, b) => a.sequence != b.sequence
                ? a.sequence.compareTo(b.sequence)
                : a.eventId.compareTo(b.eventId),
          );
    final byId = <String, PersistedOcrAttachment>{};
    for (final event in ordered) {
      try {
        final item = PersistedOcrAttachment.fromPayload(
          sessionId,
          event.payload,
        );
        byId[item.id] = item;
      } on FormatException {
        // Match v65: malformed/unknown attachments are not fabricated as cards.
      }
    }
    final result = byId.values.toList()
      ..sort(
        (a, b) => a.ordinal != b.ordinal
            ? a.ordinal.compareTo(b.ordinal)
            : a.id.compareTo(b.id),
      );
    return List.unmodifiable(result);
  }
}
