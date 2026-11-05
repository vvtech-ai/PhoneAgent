import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/agent_document_request.dart';
import '../../domain/document_import.dart';

class AgentDocumentState {
  const AgentDocumentState(this.request, {this.busy = false});
  final AgentDocumentRequest request;
  final bool busy;
}

class AgentDocumentController extends StateNotifier<AgentDocumentState?>
    implements AgentDocumentSource {
  AgentDocumentController(this.picker, this.parser) : super(null);
  final AgentDocumentPicker picker;
  final DocumentParser parser;
  Completer<ParsedDocument?>? _pending;
  bool Function() _current = () => false;
  AgentDocumentState? get snapshot => state;

  @override
  Future<ParsedDocument?> resolve(
    AgentDocumentRequest request, {
    required bool Function() isCurrent,
  }) {
    if (!mounted || !isCurrent()) return Future.value(null);
    if (_pending != null) throw StateError('Document request already active');
    _current = isCurrent;
    final pending = _pending = Completer<ParsedDocument?>();
    state = AgentDocumentState(request);
    return pending.future;
  }

  Future<void> choose() async {
    final pending = _pending, request = state?.request;
    if (pending == null || request == null || state!.busy || !_current()) {
      return;
    }
    bool current() => mounted && _pending == pending && _current();
    state = AgentDocumentState(request, busy: true);
    SelectedDocument? file;
    try {
      file = await picker.pick(request);
    } catch (_) {
      // v65 treats an unavailable system picker as cancellation.
      if (current()) cancel();
      return;
    }
    if (!current()) return;
    if (file == null) {
      cancel();
      return;
    }
    ParsedDocument failure(String status, String message) => ParsedDocument(
      status: status,
      fileName: file!.name,
      mimeType: file.mimeType,
      message: message,
    );
    try {
      if (file.size > request.maxBytes) {
        _finish(failure('FILE_TOO_LARGE', '文件超过大小限制'));
        return;
      }
      final extension = file.name.toLowerCase().split('.').last;
      if (!const [
        'md',
        'markdown',
        'txt',
        'docx',
        'xlsx',
      ].contains(extension)) {
        _finish(failure('UNSUPPORTED_TYPE', '文件类型暂不支持'));
        return;
      }
      final bytes = await file.read();
      if (!current()) return;
      if (bytes.length > request.maxBytes) {
        _finish(failure('FILE_TOO_LARGE', '文件超过大小限制'));
        return;
      }
      final result = await parser.parse(file, bytes);
      if (current()) _finish(result);
    } catch (_) {
      if (current()) _finish(failure('PARSE_FAILED', '无法解析所选文件，请重新选择'));
    }
  }

  void cancel() => _finish(
    const ParsedDocument(status: 'USER_CANCELLED', message: '用户取消了文件选择'),
  );

  /// Navigation/account invalidation is not a user cancellation submission.
  void abandon() => _finish(null);

  void _finish(ParsedDocument? result) {
    final pending = _pending;
    _pending = null;
    if (mounted) state = null;
    if (pending != null && !pending.isCompleted) pending.complete(result);
  }

  @override
  void dispose() {
    abandon();
    super.dispose();
  }
}
