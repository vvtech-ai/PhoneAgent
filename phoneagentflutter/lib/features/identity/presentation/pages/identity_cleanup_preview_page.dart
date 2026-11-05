import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/identity_providers.dart';
import '../../data/preview_identity_cleanup.dart';
import 'identity_route.dart';

class IdentityCleanupPreviewPage extends StatefulWidget {
  const IdentityCleanupPreviewPage({super.key});
  @override
  State<IdentityCleanupPreviewPage> createState() =>
      _IdentityCleanupPreviewPageState();
}

class _IdentityCleanupPreviewPageState
    extends State<IdentityCleanupPreviewPage> {
  final repository = PreviewIdentityCleanup();
  late final container = ProviderContainer(
    overrides: [
      identityRepositoryProvider.overrideWithValue(repository),
      identityDeletedEffectProvider.overrideWithValue(repository.createCleanup),
    ],
  );
  @override
  void dispose() {
    container.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => UncontrolledProviderScope(
          container: container,
          child: const Column(
            children: [
              SafeArea(
                bottom: false,
                child: Material(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('MOCK · 仅合成身份；不删除真实资料或录音'),
                  ),
                ),
              ),
              Expanded(child: IdentityRoute()),
            ],
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('身份本地处理演练')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('MOCK · 复用正式身份页面、确认弹窗和本地任务；无网络/系统存储。'),
          const SizedBox(height: 16),
          const Text('打开后删除合成身份。第一次录音清理故意失败，点击“重试本地处理”应恢复；返回核对模拟删除只发生一次。'),
          FilledButton(onPressed: _open, child: const Text('打开合成身份')),
          Text('模拟服务端删除：${repository.deletes} 次'),
          Text('模拟跳过偏好保存：${repository.skipWrites} 次'),
          Text('模拟录音清理尝试：${repository.clearAttempts} 次'),
        ],
      ),
    ),
  );
}
