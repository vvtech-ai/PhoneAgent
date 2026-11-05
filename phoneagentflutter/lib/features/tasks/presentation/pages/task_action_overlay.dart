import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'native_task_icon.dart';

class TaskActionOverlay extends StatefulWidget {
  const TaskActionOverlay({
    super.key,
    required this.anchor,
    required this.preview,
    required this.pinned,
    required this.canDelete,
  });
  final Rect anchor;
  final Widget preview;
  final bool pinned, canDelete;
  @override
  State<TaskActionOverlay> createState() => _OverlayState();
}

class _OverlayState extends State<TaskActionOverlay> {
  bool _deletePrompt = false;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final padding = MediaQuery.paddingOf(context);
        final width = math.min(widget.anchor.width, constraints.maxWidth - 32);
        final menuWidth = math.min(width, 260.0);
        final left = widget.anchor.left.clamp(
          16.0,
          math.max(16.0, constraints.maxWidth - width - 16),
        );
        final bottom = constraints.maxHeight - padding.bottom - 16;
        final top = math
            .min(widget.anchor.top, bottom - widget.anchor.height - 125)
            .clamp(
              padding.top + 16,
              math.max(padding.top + 16, bottom - widget.anchor.height - 125),
            );
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
                  child: const ColoredBox(color: Color(0xE6D8DDE5)),
                ),
              ),
            ),
            Positioned(
              left: left.toDouble(),
              top: top.toDouble(),
              width: width,
              child: AbsorbPointer(
                child: ExcludeSemantics(child: widget.preview),
              ),
            ),
            if (!_deletePrompt)
              Positioned(
                left: left.toDouble(),
                top: top + widget.anchor.height + 8,
                width: menuWidth,
                child: Material(
                  color: const Color(0xFFF3F5F9),
                  elevation: 12,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _menuRow(
                          widget.pinned ? '取消置顶' : '置顶',
                          NativeTaskGlyph.pinned,
                          const Color(0xFF182033),
                          () => Navigator.pop(context, 'pin'),
                        ),
                        const Divider(height: 1, color: Color(0xFFE6EAF0)),
                        _menuRow(
                          '删除',
                          NativeTaskGlyph.delete,
                          const Color(0xFFD92D20),
                          () => setState(() => _deletePrompt = true),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_deletePrompt) _prompt(context),
          ],
        );
      },
    ),
  );

  Widget _prompt(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Material(
        color: Colors.white,
        elevation: 14,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.canDelete ? '删除任务？' : '任务正在拨打中',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.canDelete ? '删除后，你将无法再查看此任务。' : '任务正在拨打中，暂时无法删除',
                style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.canDelete)
                    TextButton(
                      onPressed: () => setState(() => _deletePrompt = false),
                      child: const Text(
                        '取消',
                        style: TextStyle(color: Color(0xFF4B5563)),
                      ),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(
                      context,
                      widget.canDelete ? 'delete' : null,
                    ),
                    child: Text(
                      widget.canDelete ? '删除' : '知道了',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: widget.canDelete
                            ? const Color(0xFFFF3B30)
                            : const Color(0xFF0A84FF),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _menuRow(
    String text,
    NativeTaskGlyph icon,
    Color color,
    VoidCallback tap,
  ) => InkWell(
    onTap: tap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 54),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          NativeTaskIcon(icon, size: 22, color: color),
        ],
      ),
    ),
  );
}
