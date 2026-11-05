import 'package:flutter/material.dart';

/// Follows displayed transcript changes, not timer ticks or user scrolls.
class CallTranscriptViewport extends StatefulWidget {
  const CallTranscriptViewport({
    super.key,
    required this.revision,
    required this.children,
  });
  final String revision;
  final List<Widget> children;
  @override
  State<CallTranscriptViewport> createState() => _CallTranscriptViewportState();
}

class _CallTranscriptViewportState extends State<CallTranscriptViewport> {
  final _scroll = ScrollController();
  int _followGeneration = 0;
  @override
  void initState() {
    super.initState();
    _follow();
  }

  @override
  void didUpdateWidget(CallTranscriptViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) _follow();
  }

  void _follow() {
    _followAfterLayout(++_followGeneration);
  }

  void _followAfterLayout(int generation) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          generation != _followGeneration ||
          !_scroll.hasClients ||
          widget.revision.isEmpty ||
          _scroll.position.extentAfter < .5) {
        return;
      }
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
      // Lazy, variable-height rows can refine the end after scrolling.
      if (mounted && generation == _followGeneration) {
        _followAfterLayout(generation);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollStartNotification>(
        onNotification: (notification) {
          if (notification.dragDetails != null) _followGeneration++;
          return false;
        },
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.only(bottom: 10),
          children: widget.children,
        ),
      );
}
