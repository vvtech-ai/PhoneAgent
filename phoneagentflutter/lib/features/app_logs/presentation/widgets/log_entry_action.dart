import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/log_report_providers.dart';
import '../../../../core/design/native_notice.dart';
import '../controller/log_report_controller.dart';

String logEntrySummary(LogReportState state) => switch (state.phase) {
  LogReportPhase.idle => '手动上传',
  LogReportPhase.preparing => '正在打包',
  LogReportPhase.ready => '准备上传',
  LogReportPhase.uploading => '处理中',
  LogReportPhase.failed => '上传失败，点击重试',
  LogReportPhase.cleanupFailed => '已上传，重试清理',
  LogReportPhase.success => state.bundle?.hasMore == true ? '继续上传下一批' : '上传成功',
};

Future<void> submitLogEntry(BuildContext context, WidgetRef ref) async {
  final controller = ref.read(logEntryControllerProvider.notifier);
  await controller.submitFromEntry();
  if (!context.mounted ||
      !controller.mounted ||
      !identical(controller, ref.read(logEntryControllerProvider.notifier))) {
    return;
  }
  final state = controller.snapshot;
  final message = switch (state.phase) {
    LogReportPhase.success => '日志上传成功',
    LogReportPhase.cleanupFailed => '日志已上传，本地清理失败；点击日志入口仅重试清理',
    LogReportPhase.failed =>
      state.bundle == null ? '日志读取或压缩失败，未上传' : '上传结果未确认，本地日志已保留；重试可能产生重复报告',
    _ => null,
  };
  if (message != null) showNativeNotice(context, message);
}
