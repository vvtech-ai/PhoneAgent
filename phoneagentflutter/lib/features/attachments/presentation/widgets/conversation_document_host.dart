import 'package:flutter/material.dart';
import '../../../conversation/presentation/widgets/conversation_timeline_attachment.dart';
import '../../domain/document_import.dart';
import '../../domain/user_document_presentation.dart';
import '../controller/document_import_controller.dart';
import 'native_document_card.dart';

/// Owns only active user document selection/parsing, not conversation state.
class ConversationDocumentHost extends StatefulWidget {
  const ConversationDocumentHost({
    super.key,
    required this.createController,
    required this.isCurrent,
    required this.canStart,
    required this.anchor,
    required this.onReady,
    required this.onNotice,
    required this.builder,
    this.captureSubmission,
  });
  final DocumentImportController Function() createController;
  final bool Function() isCurrent, canStart;
  final int Function() anchor;
  final bool Function(DocumentTurn) onReady;
  final bool Function(DocumentTurn) Function()? captureSubmission;
  final ValueChanged<String> onNotice;
  final Widget Function(
    List<ConversationTimelineAttachment>,
    bool,
    Future<void> Function(),
  )
  builder;
  @override
  State<ConversationDocumentHost> createState() =>
      _ConversationDocumentHostState();
}

class _ConversationDocumentHostState extends State<ConversationDocumentHost> {
  late final _controller = widget.createController();
  late final _remove = _controller.addListener((_) {
    if (mounted) setState(() {});
  }, fireImmediately: false);
  bool _opening = false;
  int _anchor = 0, _sequence = 0;
  @override
  void initState() {
    super.initState();
    // Register before starting a system picker; no selection on page entry.
    _remove;
  }

  @override
  void dispose() {
    _remove();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _choose() async {
    if (_opening || !widget.isCurrent() || !widget.canStart()) return;
    final submit = widget.captureSubmission?.call() ?? widget.onReady;
    setState(() {
      _opening = true;
      _anchor = widget.anchor();
      _sequence++;
    });
    final turn = await _controller.choose();
    if (!mounted || !widget.isCurrent()) return;
    if (turn != null) {
      if (!widget.canStart() || !submit(turn)) {
        widget.onNotice('对话状态已变化，文档未发送。请重新选择文件。');
      }
    } else if (_controller.snapshot.message.isNotEmpty) {
      widget.onNotice(_controller.snapshot.message);
    }
    if (mounted) setState(() => _opening = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.snapshot;
    return widget.builder(
      [
        if (state.phase == DocumentImportPhase.parsing)
          ConversationTimelineAttachment(
            'document-pending:$_sequence',
            _anchor,
            NativeDocumentCard(
              parsing: true,
              files: state.files.map((name) => UserDocumentFile(name)).toList(),
            ),
          ),
      ],
      _opening,
      _choose,
    );
  }
}
