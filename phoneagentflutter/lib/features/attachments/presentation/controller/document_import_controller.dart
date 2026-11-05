import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/document_import.dart';

enum DocumentImportPhase { idle, picking, parsing, failed, ready }

class DocumentImportState {
  const DocumentImportState({
    this.phase = DocumentImportPhase.idle,
    this.files = const [],
    this.message = '',
    this.completed = 0,
    this.turn,
  });
  final DocumentImportPhase phase;
  final List<String> files;
  final String message;
  final int completed;
  final DocumentTurn? turn;
  bool get busy =>
      phase == DocumentImportPhase.picking ||
      phase == DocumentImportPhase.parsing;
}

class DocumentImportController extends StateNotifier<DocumentImportState> {
  DocumentImportController(this.picker, this.parser, this.nextId)
    : super(const DocumentImportState());
  final DocumentPicker picker;
  final DocumentParser parser;
  final String Function() nextId;
  int _generation = 0;
  DocumentImportState get snapshot => state;
  bool _current(int generation) => mounted && _generation == generation;

  Future<DocumentTurn?> choose() async {
    if (!mounted || state.busy) return null;
    final generation = ++_generation;
    state = const DocumentImportState(phase: DocumentImportPhase.picking);
    try {
      final files = await picker.pick();
      if (!_current(generation)) return null;
      if (files.isEmpty) {
        state = const DocumentImportState();
        return null;
      }
      if (files.any((f) => !f.supported)) {
        return _fail('仅支持选择 .docx 或 .xlsx 文件');
      }
      final oversized = files.where((f) => f.size > documentMaxBytes).toList();
      if (oversized.isNotEmpty) {
        return _fail('文件超过 5MB 限制\n${oversized.map((f) => f.name).join('\n')}');
      }
      final names = List<String>.unmodifiable(files.map((f) => f.name));
      final results = <ParsedDocument>[];
      for (final file in files) {
        if (!_current(generation)) return null;
        state = DocumentImportState(
          phase: DocumentImportPhase.parsing,
          files: names,
          completed: results.length,
        );
        final bytes = await file.read();
        if (!_current(generation)) return null;
        if (bytes.length > documentMaxBytes) {
          return _fail('文件超过 5MB 限制\n${file.name}');
        }
        final parsed = await parser.parse(file, bytes);
        if (!_current(generation)) return null;
        results.add(parsed);
      }
      final failed = results.where((r) => r.status != 'OK').firstOrNull;
      if (failed != null) {
        return _fail(failed.message.isEmpty ? '文档解析失败，请重新选择' : failed.message);
      }
      final turn = DocumentTurn(nextId(), results);
      state = DocumentImportState(
        phase: DocumentImportPhase.ready,
        files: names,
        completed: results.length,
        turn: turn,
      );
      return turn;
    } catch (_) {
      if (_current(generation)) _fail('无法读取或解析所选文件，请重新选择');
      return null;
    }
  }

  DocumentTurn? _fail(String message) {
    state = DocumentImportState(
      phase: DocumentImportPhase.failed,
      message: message,
    );
    return null;
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }
}
