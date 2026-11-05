import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/business_providers.dart';
import '../../../../app/log_report_providers.dart';
import '../../../auth/presentation/controller/auth_providers.dart';
import '../../domain/app_log_report.dart';
import '../controller/log_report_controller.dart';

class LogReportRoute extends ConsumerWidget {
  const LogReportRoute({super.key, this.onPreview});
  final VoidCallback? onPreview;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final epoch = ref.watch(loginEpochProvider);
    final accountId = ref
        .read(sessionControllerProvider.notifier)
        .credentials
        ?.accountId;
    if (accountId == null) {
      return const Scaffold(body: Center(child: Text('请先登录')));
    }
    return LogReportPage(
      key: ValueKey(epoch),
      onPreview: onPreview,
      repository: ref.watch(logReportRepositoryProvider),
    );
  }
}

class LogReportPage extends StatefulWidget {
  const LogReportPage({
    super.key,
    required this.repository,
    this.preview = false,
    this.onPreview,
  });
  final AppLogRepository repository;
  final bool preview;
  final VoidCallback? onPreview;
  @override
  State<LogReportPage> createState() => _LogReportPageState();
}

class _LogReportPageState extends State<LogReportPage> {
  late final _controller = LogReportController(widget.repository);
  late final void Function() _remove;
  @override
  void initState() {
    super.initState();
    _remove = _controller.addListener((_) {
      if (mounted) setState(() {});
    }, fireImmediately: false);
    _controller.prepare();
  }

  @override
  void dispose() {
    _remove();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.snapshot;
    final message = switch (state.phase) {
      LogReportPhase.idle || LogReportPhase.preparing => '正在压缩诊断日志…',
      LogReportPhase.ready =>
        '日志已准备：${state.bundle!.count} 条，${state.bundle!.bytes.length} 字节',
      LogReportPhase.uploading => '正在处理，请勿重复提交…',
      LogReportPhase.failed =>
        state.bundle == null ? '日志读取或压缩失败，未上传' : '上传结果未确认，本地日志已保留；重试可能产生重复报告',
      LogReportPhase.cleanupFailed => '日志已上传，本地清理失败；可仅重试清理',
      LogReportPhase.success =>
        widget.preview ? 'MOCK · 已完成压缩和模拟上传，没有发送真实日志' : '日志上传成功',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('日志上报')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            if (widget.preview) const Text('MOCK · 合成日志，真实ZIP压缩；不连接上传服务'),
            const Text('仅包含当前账号的结构化诊断事件、状态码、耗时和关联ID，不含对话正文、电话号码、身份信息或登录凭据。'),
            const SizedBox(height: 18),
            if (!widget.preview)
              const Text('点击下方上传按钮后，将发送至当前配置环境的日志服务，供问题排查使用。成功后仅清理本次已上传的日志。'),
            const SizedBox(height: 24),
            Text(message, key: const Key('log-report-status')),
            if (state.bundle?.hasMore == true)
              const Text('日志较多，本次只处理一批；其余日志仍保留，成功后可继续准备下一批。'),
            if (state.busy) const LinearProgressIndicator(),
            const SizedBox(height: 20),
            if (state.phase == LogReportPhase.success &&
                state.bundle?.hasMore == true)
              FilledButton(
                onPressed: _controller.prepareNext,
                child: const Text('继续准备剩余日志'),
              ),
            if (!state.busy && state.phase != LogReportPhase.success)
              FilledButton(
                onPressed: state.phase == LogReportPhase.cleanupFailed
                    ? _controller.retryCleanup
                    : state.bundle == null
                    ? _controller.prepare
                    : _controller.upload,
                child: Text(
                  state.phase == LogReportPhase.cleanupFailed
                      ? '仅重试本地清理'
                      : state.bundle == null
                      ? '重新准备日志'
                      : widget.preview
                      ? '模拟上传合成日志'
                      : '上传诊断日志',
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('返回'),
            ),
            if (widget.onPreview != null)
              TextButton(
                onPressed: widget.onPreview,
                child: const Text('合成日志上传演练（MOCK）'),
              ),
          ],
        ),
      ),
    );
  }
}
