enum OcrStatus { processing, success, failed }

enum OcrFailure { emptyText, recognition, refinement, cloudCommit }

class OcrField {
  const OcrField(this.label, this.value);
  final String label, value;
}

class OcrContent {
  OcrContent({
    required this.fullText,
    List<String> segments = const [],
    List<OcrField> fields = const [],
  }) : segments = List.unmodifiable(segments),
       fields = List.unmodifiable(fields);
  final String fullText;
  final List<String> segments;
  final List<OcrField> fields;
  bool get collapsible => fullText.length > 50;
  String displayText(bool expanded) => expanded || !collapsible
      ? fullText
      : '${fullText.substring(0, 50).trimRight()}……';
  String get summary {
    final labels = fields.map((f) => f.label).toSet().take(3).join('、');
    return labels.isEmpty ? '已提取图片中的文字信息' : '已从图片中提取$labels等信息';
  }
}

class OcrAttachment {
  const OcrAttachment({
    required this.id,
    required this.imageRef,
    required this.anchor,
    required this.ordinal,
    this.status = OcrStatus.processing,
    this.content,
    this.failure,
  });
  final String id, imageRef;
  final int anchor, ordinal;
  final OcrStatus status;
  final OcrContent? content;
  final OcrFailure? failure;
  OcrAttachment finish({OcrContent? content, OcrFailure? failure}) =>
      OcrAttachment(
        id: id,
        imageRef: imageRef,
        anchor: anchor,
        ordinal: ordinal,
        status: failure == null ? OcrStatus.success : OcrStatus.failed,
        content: content,
        failure: failure,
      );
  String get failureMessage => switch (failure) {
    OcrFailure.emptyText => '未识别到有效文字，请重新选择图片',
    OcrFailure.refinement => '图片文字整理失败，请重新选择图片',
    OcrFailure.cloudCommit => '图片保存失败，请重新选择图片',
    _ => '图片文字识别失败，请重新选择图片',
  };
}

class OcrRecognition {
  const OcrRecognition(this.rawText, this.segments);
  final String rawText;
  final List<String> segments;
}

class OcrCommitFailure implements Exception {
  const OcrCommitFailure(this.reason);
  final OcrFailure reason;
}

abstract interface class OcrRecognizer {
  Future<OcrRecognition> recognize(String imageRef);
}

abstract interface class OcrCommitter {
  Future<OcrContent> commit(
    OcrAttachment attachment,
    OcrRecognition recognition,
  );
}
