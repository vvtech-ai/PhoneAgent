import 'package:phone_agent/features/auth/presentation/pages/auth_route.dart';
import 'package:phone_agent/features/auth/presentation/controller/session_controller.dart';
import 'package:phone_agent/app/invite_registration_providers.dart';
import 'package:phone_agent/features/invite/domain/invite_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'auth_scenario.dart';

void main() {
  if (!kDebugMode) throw UnsupportedError('Preview is debug-only');
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  runApp(const MaterialApp(home: AuthPreviewPage()));
}

/// Auth-only preview uses the production form/controller and stops at the
/// authenticated boundary. Full shell navigation is covered by shell previews.
class AuthScenarioApp extends StatelessWidget {
  const AuthScenarioApp({required this.scenario, super.key});
  final AuthScenario scenario;
  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(
        AppConfig.parse(environment: 'local', apiBaseUrl: ''),
      ),
      authGatewayProvider.overrideWithValue(scenario),
      sessionStoreProvider.overrideWithValue(scenario),
      inviteStoreProvider.overrideWithValue(MemoryInviteStore()),
    ],
    child: MaterialApp(
      home: Consumer(
        builder: (context, ref, _) {
          final session = ref.watch(sessionControllerProvider);
          return session.phase == SessionPhase.signedIn
              ? const Scaffold(body: Center(child: Text('MOCK 登录成功')))
              : const AuthRoute();
        },
      ),
    ),
  );
}

class AuthPreviewPage extends StatefulWidget {
  const AuthPreviewPage({super.key});
  @override
  State<AuthPreviewPage> createState() => _PreviewState();
}

class _PreviewState extends State<AuthPreviewPage> {
  AuthScenario scenario = AuthScenario(
    AuthScenarioKind.invitation,
    delay: const Duration(milliseconds: 250),
  );

  static const labels = {
    AuthScenarioKind.invitation: '邀请码',
    AuthScenarioKind.direct: '直接登录',
    AuthScenarioKind.saveFailure: '保存失败',
    AuthScenarioKind.restoreFailure: '恢复失败',
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFFFFF3CD),
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                const Text('MOCK · 无短信/无网络 · 不读取真实登录态'),
                const Text('合成号码 13800000000 / 验证码 123456 / 邀请码 DEMO'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final entry in labels.entries)
                      TextButton(
                        onPressed: () => setState(() {
                          scenario = AuthScenario(
                            entry.key,
                            delay: const Duration(milliseconds: 250),
                          );
                        }),
                        child: Text('重置：${entry.value}'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: AuthScenarioApp(
              key: ObjectKey(scenario),
              scenario: scenario,
            ),
          ),
        ],
      ),
    ),
  );
}
