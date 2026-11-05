import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/business_providers.dart';
import '../../../../app/dial_permission_providers.dart';
import '../../../../app/dial_recent_providers.dart';
import '../../../../app/translation_location_providers.dart';
import '../../../translation/data/preview_translation_location.dart';
import '../../../translation/presentation/controller/translation_setup_controller.dart';
import '../../../translation/presentation/widgets/translation_presets.dart';
import '../../data/preview_dial_permission_port.dart';
import '../../data/dial_recent_sources.dart';
import '../../domain/dial_permission.dart';
import '../../domain/dial_recent_source.dart';
import '../widgets/dial_permission_host.dart';

class DialPermissionPreviewPage extends StatelessWidget {
  const DialPermissionPreviewPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('拨号权限演练')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('MOCK · 不访问系统权限、真实位置、账号或通话记录。不发起电话。'),
        for (final scenario in ['Android 拒绝后去设置', 'Android 直接授权', 'iOS 直接授权'])
          ListTile(
            title: Text(scenario),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => _PreviewSession(scenario: scenario),
              ),
            ),
          ),
      ],
    ),
  );
}

class _PreviewSession extends StatefulWidget {
  const _PreviewSession({required this.scenario});
  final String scenario;
  @override
  State<_PreviewSession> createState() => _PreviewSessionState();
}

class _PreviewSessionState extends State<_PreviewSession> {
  late final port = PreviewDialPermissionPort(
    supportsCallLog: !widget.scenario.startsWith('iOS'),
    allowLocation: !widget.scenario.contains('拒绝'),
  );
  final memory = DialPermissionMemory();
  final location = PreviewTranslationLocation();
  final setup = TranslationSetupController();
  int revision = 0;
  String result = '';
  @override
  void dispose() {
    setup.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      loginEpochProvider.overrideWithValue(0),
      dialPermissionPortProvider.overrideWithValue(port),
      dialPermissionMemoryProvider.overrideWithValue(memory),
      translationLocationSourceProvider.overrideWithValue(location),
      translationLocationStoreProvider.overrideWithValue(location),
      systemDialRecentSourceProvider.overrideWithValue(
        const UnavailableDialRecentSource(DialRecentAccess.unsupported),
      ),
      appDialRecentSourceProvider.overrideWithValue(
        const UnavailableDialRecentSource(DialRecentAccess.unsupported),
      ),
    ],
    child: DialPermissionHost(
      key: ValueKey(revision),
      ready: true,
      enabled: setup.snapshot.enabled,
      onEnabled: (value) => setState(() => setup.enable(value)),
      builder: (context, permission) => Scaffold(
        appBar: AppBar(title: Text(widget.scenario)),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('MOCK · 共享正式权限流程；系统接口为内存模拟'),
            Text('阶段：${permission.snapshot.stage.name}'),
            SwitchListTile(
              title: const Text('实时翻译'),
              value: setup.snapshot.enabled,
              onChanged: permission.toggle,
            ),
            FilledButton(
              onPressed: () async {
                final confirmed = await showTranslationPresets(
                  context,
                  setup,
                  permission.toggle,
                );
                if (mounted) {
                  setState(
                    () => result = confirmed ? '仅确认配置，演练未发起电话' : '已关闭配置',
                  );
                }
              },
              child: const Text('打开拨号配置'),
            ),
            OutlinedButton(
              onPressed: () => setState(() {
                memory.resetLocation();
                revision++;
                setup.enable(true);
              }),
              child: const Text('重置 App 位置提示（保留系统事实）'),
            ),
            Text(result),
            const Divider(),
            Text('系统位置：${port.grant.name} · 地区读取：${location.requests}'),
            Text(
              '位置提示：${memory.locationShown} · 记录申请标记：${memory.callLogRequested}',
            ),
            const Text('接口顺序（合成）：'),
            Text(port.trace.join('\n')),
          ],
        ),
      ),
    ),
  );
}
