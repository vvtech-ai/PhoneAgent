import 'package:flutter/material.dart';
import '../../../conversation/domain/history/conversation_ocr_boundary.dart';
import '../../../conversation/presentation/widgets/conversation_timeline_attachment.dart';
import '../controller/ocr_session_controller.dart';
import 'ocr_attachment_card.dart';

/// Renders the same OCR state on every platform; does not own the session.
class ConversationOcrHost extends StatefulWidget {
  const ConversationOcrHost({
    super.key,
    required this.controller,
    required this.boundary,
    required this.builder,
  });
  final OcrSessionController? controller;
  final ConversationOcrBoundary boundary;
  final Widget Function(List<ConversationTimelineAttachment>) builder;
  @override
  State<ConversationOcrHost> createState() => _ConversationOcrHostState();
}

class _ConversationOcrHostState extends State<ConversationOcrHost> {
  void Function()? _remove;
  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    _remove = widget.controller?.addListener((_) {
      if (mounted) setState(() {});
    }, fireImmediately: false);
  }

  @override
  void didUpdateWidget(covariant ConversationOcrHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _remove?.call();
      _listen();
    }
  }

  @override
  void dispose() {
    _remove?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller?.snapshot;
    return widget.builder([
      for (final item in state?.processing.attachments ?? [])
        if (state!.images[item.id] case final bytes?)
          ConversationTimelineAttachment(
            item.id,
            widget.boundary.displayBoundaryFor(item.anchor),
            OcrAttachmentCard(
              key: ValueKey('ocr:${item.id}'),
              attachment: item,
              image: MemoryImage(bytes),
            ),
          ),
    ]);
  }
}
