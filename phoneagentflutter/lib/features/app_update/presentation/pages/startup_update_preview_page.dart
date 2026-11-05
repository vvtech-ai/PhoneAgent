import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/app_update_providers.dart';
import '../../../../app/business_providers.dart';
import '../../data/preview_startup_update.dart';
import '../../data/preview_update_install_port.dart';
import '../../domain/app_update.dart';
import '../controller/startup_update_controller.dart';
import '../controller/update_install_controller.dart';
import '../widgets/startup_update_host.dart';
import 'update_install_page.dart';

class StartupUpdateScenariosPage extends StatelessWidget {
  const StartupUpdateScenariosPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('MOCK · 启动更新场景')),
    body: ListView(
      children: [
        for (final entry in const {
          StartupUpdateScenario.optional: '新版本提示与稍后',
          StartupUpdateScenario.forced: '强制更新与安装取消',
          StartupUpdateScenario.sameDay: '当天已检查不重复弹出',
          StartupUpdateScenario.offlineForce: '强制标记下离线失败与重试',
          StartupUpdateScenario.recovered: '离线恢复已下载任务',
          StartupUpdateScenario.missingDownload: '恢复失败刷新下载信息',
        }.entries)
          ListTile(
            title: Text(entry.value),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(builder: (_) => _Scenario(entry.key)),
            ),
          ),
      ],
    ),
  );
}

class _Scenario extends StatefulWidget {
  const _Scenario(this.scenario);
  final StartupUpdateScenario scenario;
  @override
  State<_Scenario> createState() => _ScenarioState();
}

class _ScenarioState extends State<_Scenario> {
  late final backend = PreviewStartupUpdate(widget.scenario);
  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      startupUpdateSupportedProvider.overrideWithValue(true),
      loginEpochProvider.overrideWithValue(-1),
      startupUpdateControllerProvider.overrideWith(
        (ref) => StartupUpdateController(
          source: backend.source,
          repository: backend,
          store: backend.store,
          recovery: backend,
          isCurrent: () => mounted,
        ),
      ),
    ],
    child: Consumer(
      builder: (context, ref, _) {
        final controls = _Controls(backend: backend);
        return StartupUpdateHost(
          previewControls: controls,
          installationBuilder: (offer, refresh) => _PreviewInstall(
            offer.app,
            offer.release,
            recovered:
                offer.recovered &&
                widget.scenario == StartupUpdateScenario.recovered,
            onRefresh: refresh,
            controls: controls,
          ),
          child: Scaffold(
            appBar: AppBar(title: const Text('MOCK · 启动更新')),
            body: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('合成首页：没有真实账号、网络、APK、系统权限或安装操作。'),
                const SizedBox(height: 20),
                controls,
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _Controls extends ConsumerWidget {
  const _Controls({required this.backend});
  final PreviewStartupUpdate backend;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(startupUpdateControllerProvider);
    final controller = ref.read(startupUpdateControllerProvider.notifier);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('MOCK · 版本请求次数：${backend.checks}'),
        Text('MOCK · 持久强制标记：${backend.store.record.forceRequired}'),
        TextButton(
          onPressed: state.busy
              ? null
              : () {
                  backend.repaired = true;
                  controller.refresh();
                },
          child: const Text('模拟网络恢复并检查'),
        ),
        TextButton(
          onPressed: state.busy
              ? null
              : () => controller.acceptManual(
                  PreviewUpdateInstallPort.app,
                  const AppUpdateRelease(
                    hasUpdate: false,
                    packageName: 'com.example.preview',
                  ),
                ),
          child: const Text('模拟服务端确认无需更新'),
        ),
      ],
    );
  }
}

class _PreviewInstall extends StatefulWidget {
  const _PreviewInstall(
    this.app,
    this.release, {
    required this.recovered,
    this.onRefresh,
    required this.controls,
  });
  final InstalledApp app;
  final AppUpdateRelease release;
  final bool recovered;
  final VoidCallback? onRefresh;
  final Widget controls;
  @override
  State<_PreviewInstall> createState() => _PreviewInstallState();
}

class _PreviewInstallState extends State<_PreviewInstall> {
  late final port = PreviewUpdateInstallPort(
    widget.recovered
        ? UpdateInstallScenario.restored
        : UpdateInstallScenario.normal,
  );
  late final controller = UpdateInstallController(
    app: widget.app,
    release: widget.release,
    port: port,
    isCurrent: () => mounted,
  );
  @override
  Widget build(BuildContext context) => UpdateInstallPage(
    controller: controller,
    disposeController: true,
    dialog: true,
    autoStart: !widget.recovered,
    onRefresh: widget.onRefresh,
    previewControls: (state) => Column(
      children: [
        if (state.phase == UpdateInstallPhase.permission)
          TextButton(
            onPressed: () {
              port.allowed = true;
              controller.resumed();
            },
            child: const Text('模拟安装授权返回'),
          ),
        if (state.phase == UpdateInstallPhase.installing)
          TextButton(
            onPressed: controller.resumed,
            child: const Text('模拟取消系统安装'),
          ),
        widget.controls,
      ],
    ),
  );
}
