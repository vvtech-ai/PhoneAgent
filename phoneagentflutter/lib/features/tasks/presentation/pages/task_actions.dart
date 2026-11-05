import 'package:flutter/material.dart';
import '../../domain/task_records.dart';
import 'task_action_overlay.dart';

Future<void> showTaskActions(
  BuildContext context,
  TaskRecord row, {
  required Widget preview,
  required ValueChanged<TaskRecord> onPin,
  required ValueChanged<TaskRecord> onDelete,
}) async {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return;
  final anchor = box.localToGlobal(Offset.zero) & box.size;
  final action = await showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭操作菜单',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 140),
    pageBuilder: (_, __, ___) => TaskActionOverlay(
      anchor: anchor,
      preview: preview,
      pinned: row.pinnedAt != null,
      canDelete: row.canDelete,
    ),
  );
  if (!context.mounted) return;
  if (action == 'pin') onPin(row);
  if (action == 'delete' && row.canDelete) onDelete(row);
}
