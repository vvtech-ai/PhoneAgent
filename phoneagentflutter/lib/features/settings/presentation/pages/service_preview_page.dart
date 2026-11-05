import 'package:flutter/material.dart';
import '../../../../core/design/shell_tokens.dart';
import '../controller/service_preview_controller.dart';

class ServicePreviewPage extends StatefulWidget {
  const ServicePreviewPage({super.key, required this.service});
  final PreviewService service;
  @override
  State<ServicePreviewPage> createState() => _ServicePreviewPageState();
}

class _ServicePreviewPageState extends State<ServicePreviewPage> {
  late final controller = ServicePreviewController(widget.service);
  late final void Function() _remove;
  @override
  void initState() {
    super.initState();
    _remove = controller.addListener((_) {
      if (mounted) setState(() {});
    }, fireImmediately: false);
  }

  @override
  void dispose() {
    _remove();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = controller.snapshot;
    final logs = widget.service == PreviewService.logs;
    final message = switch (state.phase) {
      ServicePreviewPhase.idle => logs ? '准备合成诊断数据' : '准备检查模拟版本',
      ServicePreviewPhase.checking => '正在检查模拟版本…',
      ServicePreviewPhase.latest => 'MOCK · 当前已是最新版本',
      ServicePreviewPhase.available => 'MOCK · 发现可用版本，等待下载',
      ServicePreviewPhase.compressing => 'MOCK · 正在压缩合成日志…',
      ServicePreviewPhase.uploading => 'MOCK · 正在模拟上传…',
      ServicePreviewPhase.downloading => 'MOCK · 正在模拟下载…',
      ServicePreviewPhase.failed =>
        logs ? 'MOCK · 上传失败，可以重试' : 'MOCK · 下载或校验失败，不允许安装',
      ServicePreviewPhase.success => 'MOCK · 上报成功，未上传任何真实文件',
      ServicePreviewPhase.ready => 'MOCK · 下载与校验完成，可以演练安装交接',
      ServicePreviewPhase.handoff => 'MOCK · 已模拟系统安装交接，没有安装 APK',
    };
    return Scaffold(
      appBar: AppBar(title: Text(logs ? '日志上报演练' : 'Android 更新演练')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            const Text('MOCK · 隔离交互演练', style: ShellTokens.section),
            const SizedBox(height: 12),
            Text(
              logs
                  ? '仅使用合成状态，不读取、压缩或上传设备日志。'
                  : '不连接更新服务、不下载或安装 APK；不代表已验证无缝升级。',
            ),
            const SizedBox(height: 24),
            Text(message, key: const Key('service-preview-status')),
            if (state.busy)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: LinearProgressIndicator(
                  value: state.progress == 0 ? null : state.progress,
                ),
              ),
            if (!logs && !state.busy)
              SwitchListTile(
                title: const Text('演练无新版本'),
                value: controller.latest,
                onChanged: (v) => setState(() => controller.latest = v),
              ),
            SwitchListTile(
              title: const Text('模拟下一次传输失败'),
              value: controller.failNext,
              onChanged: state.busy
                  ? null
                  : (v) => setState(() => controller.failNext = v),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: state.busy
                  ? null
                  : state.phase == ServicePreviewPhase.ready
                  ? controller.handoff
                  : controller.run,
              child: Text(
                state.busy
                    ? '处理中…'
                    : logs
                    ? '模拟上报 / 重试'
                    : state.phase == ServicePreviewPhase.ready
                    ? '模拟安装交接'
                    : [
                        ServicePreviewPhase.available,
                        ServicePreviewPhase.failed,
                      ].contains(state.phase)
                    ? '模拟下载 / 重试'
                    : '模拟检查更新',
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('退出演练'),
            ),
          ],
        ),
      ),
    );
  }
}
