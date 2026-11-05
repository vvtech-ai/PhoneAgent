import 'package:flutter/material.dart';
import '../../data/preview_update_install_port.dart';
import '../controller/update_install_controller.dart';
import 'update_install_page.dart';

class UpdateInstallPreview extends StatelessWidget {
  const UpdateInstallPreview({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('MOCK · 更新安装场景')),
    body: SafeArea(
      child: ListView(
        children: [
          for (final entry in const {
            UpdateInstallScenario.normal: '正常下载与安装交接',
            UpdateInstallScenario.denied: '拒绝授权后重试',
            UpdateInstallScenario.failed: '下载失败后重试',
            UpdateInstallScenario.restored: '恢复已下载任务',
            UpdateInstallScenario.paused: '网络暂停后恢复',
          }.entries)
            ListTile(
              title: Text(entry.value),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => _InstallScenario(scenario: entry.key),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _InstallScenario extends StatefulWidget {
  const _InstallScenario({required this.scenario});
  final UpdateInstallScenario scenario;
  @override
  State<_InstallScenario> createState() => _InstallScenarioState();
}

class _InstallScenarioState extends State<_InstallScenario> {
  late final _port = PreviewUpdateInstallPort(widget.scenario);
  late final _controller = UpdateInstallController(
    app: PreviewUpdateInstallPort.app,
    release: PreviewUpdateInstallPort.release,
    port: _port,
    isCurrent: () => mounted,
  );
  @override
  Widget build(BuildContext context) => UpdateInstallPage(
    controller: _controller,
    disposeController: true,
    previewControls: (state) => Column(
      children: [
        if (state.phase == UpdateInstallPhase.paused)
          OutlinedButton(
            onPressed: () => _port.paused = false,
            child: const Text('模拟网络恢复'),
          ),
        if (state.phase == UpdateInstallPhase.permission && !state.busy) ...[
          OutlinedButton(
            onPressed: () {
              _port.allowed = true;
              _controller.resumed();
            },
            child: const Text('模拟已授权并返回'),
          ),
          OutlinedButton(
            onPressed: () {
              _port.allowed = false;
              _controller.resumed();
            },
            child: const Text('模拟拒绝并返回'),
          ),
        ],
        if (state.phase == UpdateInstallPhase.installing && !state.busy)
          OutlinedButton(
            onPressed: _controller.resumed,
            child: const Text('模拟取消系统安装并返回'),
          ),
      ],
    ),
  );
}
