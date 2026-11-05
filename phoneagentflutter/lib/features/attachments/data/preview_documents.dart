import 'dart:typed_data';
import '../domain/document_import.dart';

enum DocumentPreviewScenario {
  success,
  unsupported,
  oversized,
  failure,
  cancelled,
}

/// Explicitly selected synthetic data; never opens files or contacts an API.
class PreviewDocuments implements DocumentPicker, DocumentParser {
  PreviewDocuments(this.scenario);
  final DocumentPreviewScenario scenario;
  @override
  Future<List<SelectedDocument>> pick() async {
    if (scenario == DocumentPreviewScenario.cancelled) return [];
    return [
      for (final name
          in scenario == DocumentPreviewScenario.unsupported
              ? ['不支持.pdf']
              : ['合成任务.docx', '合成名单.xlsx'])
        SelectedDocument(
          name: name,
          mimeType: 'application/octet-stream',
          size: scenario == DocumentPreviewScenario.oversized
              ? documentMaxBytes + 1
              : 10,
          read: () async => Uint8List.fromList([1, 2, 3]),
        ),
    ];
  }

  @override
  Future<ParsedDocument> parse(SelectedDocument file, Uint8List bytes) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (scenario == DocumentPreviewScenario.failure &&
        file.name.endsWith('.xlsx')) {
      return const ParsedDocument(
        status: 'PARSE_FAILED',
        message: 'MOCK：第二个文件解析失败',
      );
    }
    return ParsedDocument(
      status: 'OK',
      fileName: file.name,
      mimeType: file.mimeType,
      content: '这是仅用于UI演练的合成资料，不包含真实联系人或外呼号码。',
      charCount: 31,
    );
  }
}
