import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/app_update_providers.dart';
import '../../../../core/design/shell_tokens.dart';
import '../controller/app_update_controller.dart';
import 'update_install_route.dart';

class AppUpdateRoute extends ConsumerWidget {
  const AppUpdateRoute({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appUpdateControllerProvider);
    return AppUpdatePage(
      state: state,
      onCheck: () => ref.read(appUpdateControllerProvider.notifier).check(),
      onInstall: state.app != null && state.release?.hasUpdate == true
          ? () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => UpdateInstallRoute(
                  launch: (app: state.app!, release: state.release!),
                ),
              ),
            )
          : null,
    );
  }
}

class AppUpdatePage extends StatelessWidget {
  const AppUpdatePage({
    super.key,
    required this.state,
    required this.onCheck,
    this.previewControls,
    this.onInstallPreview,
    this.onInstall,
  });
  final AppUpdateState state;
  final VoidCallback onCheck;
  final Widget? previewControls;
  final VoidCallback? onInstallPreview;
  final VoidCallback? onInstall;
  @override
  Widget build(BuildContext context) {
    final release = state.release, app = state.app;
    return Scaffold(
      appBar: AppBar(title: const Text('版本更新')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            if (previewControls != null) ...[
              const Text('MOCK · 版本检查演练', style: ShellTokens.section),
              const Text('合成版本信息，不读取设备、不连接更新服务。'),
              previewControls!,
              const SizedBox(height: 16),
            ],
            if (app != null) ...[
              Text(
                '当前版本：${app.versionName} (${app.versionCode})',
                style: ShellTokens.cardTitle,
              ),
              Text('应用包名：${app.packageName}', style: ShellTokens.subtitle),
            ] else
              const Text('读取当前安装版本后检查更新', style: ShellTokens.cardTitle),
            const SizedBox(height: 24),
            if (state.busy) const LinearProgressIndicator(),
            if (state.error.isNotEmpty)
              Text(state.error, key: const Key('update-error')),
            if (release != null)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: ShellTokens.cardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      !release.hasUpdate
                          ? '当前已是最新版本'
                          : release.forceUpdate
                          ? '发现重要版本更新'
                          : '发现新版本',
                      style: ShellTokens.cardTitle,
                    ),
                    if (release.hasUpdate) ...[
                      const SizedBox(height: 12),
                      Text('新版本：${release.versionName}'),
                      if (release.fileSize != null)
                        Text('安装包大小：${release.fileSize} 字节'),
                      const SizedBox(height: 12),
                      Text(
                        release.releaseNotes.isEmpty
                            ? '本次更新包含体验优化与问题修复。'
                            : release.releaseNotes,
                      ),
                      if (release.forceUpdate) ...[
                        const SizedBox(height: 12),
                        const Text('服务端标记为强制更新，请完成更新后继续使用。'),
                      ],
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: state.busy ? null : onCheck,
              child: Text(
                state.busy
                    ? '检查中…'
                    : state.error.isNotEmpty
                    ? '重试检查'
                    : '检查更新',
              ),
            ),
            const SizedBox(height: 18),
            if (onInstall != null && release?.hasUpdate == true)
              FilledButton(
                onPressed: state.busy ? null : onInstall,
                child: const Text('立即更新'),
              ),
            const Text(
              '仅点击检查不会下载或安装。正式签名及旧数据无缝升级仍需专项验收。',
              style: ShellTokens.subtitle,
            ),
            if (onInstallPreview != null)
              TextButton(
                onPressed: onInstallPreview,
                child: const Text('继续下载与安装演练（MOCK）'),
              ),
          ],
        ),
      ),
    );
  }
}
