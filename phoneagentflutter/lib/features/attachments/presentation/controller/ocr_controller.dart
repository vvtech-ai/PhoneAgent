import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/ocr_attachment.dart';

class OcrState {
  const OcrState(this.attachments, {this.processingId});
  final List<OcrAttachment> attachments;
  final String? processingId;
  bool get busy => processingId != null;
  List<OcrAttachment> get successful => attachments
      .where((a) => a.status == OcrStatus.success)
      .toList(growable: false);
}

/// Recognition/commit ports are separate from presentation and session transport.
class OcrController extends StateNotifier<OcrState> {
  OcrController(this.recognizer, this.committer, this.nextId)
    : super(const OcrState([]));
  final OcrRecognizer recognizer;
  final OcrCommitter committer;
  final String Function() nextId;
  int _generation = 0, _ordinal = 0;
  OcrState get snapshot => state;
  bool _current(int generation) => mounted && generation == _generation;

  void reserveOrdinal(int next) {
    if (mounted && next > _ordinal) _ordinal = next;
  }

  Future<void> select(String imageRef, int anchor, {String? id}) async {
    if (!mounted || state.busy) return;
    final generation = ++_generation;
    final item = OcrAttachment(
      id: id ?? nextId(),
      imageRef: imageRef,
      anchor: anchor < 0 ? 0 : anchor,
      ordinal: _ordinal++,
    );
    state = OcrState(
      List.unmodifiable([...state.attachments, item]),
      processingId: item.id,
    );
    OcrRecognition recognition;
    try {
      recognition = await recognizer.recognize(imageRef);
    } catch (_) {
      if (_current(generation)) {
        _finish(item.finish(failure: OcrFailure.recognition));
      }
      return;
    }
    if (!_current(generation)) return;
    if (recognition.rawText.trim().isEmpty) {
      _finish(item.finish(failure: OcrFailure.emptyText));
      return;
    }
    try {
      final content = await committer.commit(item, recognition);
      if (_current(generation)) _finish(item.finish(content: content));
    } catch (error) {
      if (_current(generation)) {
        _finish(
          item.finish(
            failure: error is OcrCommitFailure
                ? error.reason
                : OcrFailure.cloudCommit,
          ),
        );
      }
    }
  }

  /// Durable success can arrive through history before the upload response.
  void synchronize(Iterable<OcrAttachment> history) {
    if (!mounted) return;
    final items = {for (final item in state.attachments) item.id: item};
    var processing = state.processingId;
    for (final item in history) {
      if (item.status != OcrStatus.success || item.content == null) continue;
      final local = items[item.id];
      items[item.id] = OcrAttachment(
        id: item.id,
        imageRef: local?.imageRef ?? item.imageRef,
        anchor: local?.anchor ?? item.anchor,
        ordinal: item.ordinal,
        status: OcrStatus.success,
        content: item.content,
      );
      if (item.ordinal >= _ordinal) _ordinal = item.ordinal + 1;
      if (processing == item.id) {
        processing = null;
        _generation++;
      }
    }
    final ordered = items.values.toList()
      ..sort((a, b) {
        final order = a.ordinal.compareTo(b.ordinal);
        return order == 0 ? a.id.compareTo(b.id) : order;
      });
    state = OcrState(List.unmodifiable(ordered), processingId: processing);
  }

  void _finish(OcrAttachment item) => state = OcrState(
    List.unmodifiable([
      for (final current in state.attachments)
        current.id == item.id ? item : current,
    ]),
  );

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }
}
