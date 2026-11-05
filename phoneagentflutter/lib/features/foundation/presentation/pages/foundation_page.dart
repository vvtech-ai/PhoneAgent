import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../auth/domain/auth_session.dart';

/// Temporary B0 engineering surface, not a migrated product page.
class FoundationPage extends StatelessWidget {
  const FoundationPage({super.key, required this.config, this.session});

  final AppConfig config;
  final AuthSession? session;

  @override
  Widget build(BuildContext context) {
    final message = switch (config.issue) {
      ConfigIssue.unknownEnvironment => '环境无效，请使用 local、dev 或 prod。',
      ConfigIssue.missingApi => '尚未配置 API，未连接业务服务。',
      ConfigIssue.invalidApi => 'API 地址无效，请检查开发配置。',
      ConfigIssue.insecureRelease => '正式配置必须使用 prod 和 HTTPS。',
      null => '配置校验通过；业务模块尚未接入。',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('PhoneAgent')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.developer_mode, size: 48),
            const SizedBox(height: 24),
            Text(
              session == null ? 'Flutter 工程已启动' : '登录成功',
              key: const ValueKey('authenticated-status'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              session == null
                  ? 'B0 · 双端工程验证页\n此页面不是产品设计稿复刻。'
                  : '登录会话已保存；首页及首次身份引导尚在迁移中。\n此页面是工程验证页，不是产品首页。',
            ),
            if (session != null) Text(session!.maskedPhone),
            const SizedBox(height: 24),
            Text('环境：${config.environment?.name ?? 'invalid'}'),
            const SizedBox(height: 8),
            Text(
              session == null ? message : '会话已就绪',
              key: const ValueKey('configuration-status'),
            ),
            const SizedBox(height: 24),
            const Text('不发起身份采集或通话请求。'),
          ],
        ),
      ),
    );
  }
}
