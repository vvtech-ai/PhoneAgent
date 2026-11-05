import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/mobile_preview.dart';
import 'package:phone_agent/app/points_providers.dart';
import 'package:phone_agent/app/points_session_providers.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/points/domain/points_activation.dart';
import 'package:phone_agent/features/points/domain/points_wallet.dart';
import 'package:phone_agent/features/points/domain/points_wallet_cache.dart';
import 'package:phone_agent/features/points/presentation/pages/points_wallet_route.dart';
import 'package:phone_agent/features/points/presentation/widgets/points_session_host.dart';

void main() {
  if (!kDebugMode) throw UnsupportedError('Preview is debug-only');
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (_, child) => MobilePreview(child: child!),
      home: const PointsSessionPreviewPage(),
    ),
  );
}

class PointsSessionPreviewPage extends StatefulWidget {
  const PointsSessionPreviewPage({super.key});

  @override
  State<PointsSessionPreviewPage> createState() =>
      _PointsSessionPreviewPageState();
}

class _PointsSessionPreviewPageState extends State<PointsSessionPreviewPage> {
  final server = _Server();
  late final ProviderContainer container;
  late final Future<void> restored;

  @override
  void initState() {
    super.initState();
    container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(_Store()),
        pointsWalletRepositoryProvider.overrideWithValue(server),
        pointsWalletCacheProvider.overrideWithValue(
          const EmptyPointsWalletCache(),
        ),
        pointsActivationRepositoryProvider.overrideWithValue(server),
      ],
    );
    restored = container.read(sessionControllerProvider.notifier).restore();
  }

  @override
  void dispose() {
    container.dispose();
    server.activations.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => UncontrolledProviderScope(
    container: container,
    child: FutureBuilder<void>(
      future: restored,
      builder: (_, state) => state.connectionState == ConnectionState.done
          ? _Preview(server)
          : const Center(child: CircularProgressIndicator()),
    ),
  );
}

class _Preview extends StatefulWidget {
  const _Preview(this.server);
  final _Server server;
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  int _mount = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          const Text('会话积分同步 · MOCK'),
          const Text('仅合成账号和内存服务，不发短信、不访问真实积分'),
          ValueListenableBuilder<int>(
            valueListenable: widget.server.activations,
            builder: (_, value, __) => Text('合成激活请求：$value'),
          ),
          TextButton(
            onPressed: () => setState(() => _mount++),
            child: Text(_mount == 0 ? '开始会话同步' : '重新挂载页面'),
          ),
          Expanded(
            child: _mount == 0
                ? const Center(child: Text('点击开始验证恢复会话'))
                : PointsSessionHost(
                    key: ValueKey(_mount),
                    child: const PointsWalletRoute(),
                  ),
          ),
        ],
      ),
    ),
  );
}

class _Server implements PointsActivationRepository, PointsWalletRepository {
  final activations = ValueNotifier(0);
  int _balance = 800;
  PointsAccount get snapshot => PointsAccount(
    totalBalance: _balance,
    availableBalance: _balance,
    heldBalance: 0,
    updatedAt: '2026-09-18T00:00:00Z',
  );
  @override
  Future<PointsActivation> activate() async {
    activations.value++;
    _balance = 900;
    return PointsActivation(snapshot, const [
      PointsGrant('DAILY_LOGIN_GRANT', 100, '2026-09-18'),
    ]);
  }

  @override
  Future<PointsAccount> account() async => snapshot;
  @override
  Future<PointsLedgerPage> ledger(int page, {int size = 20}) async =>
      PointsLedgerPage(
        page: page,
        size: size,
        totalElements: 1,
        totalPages: 1,
        items: [
          PointsLedgerItem(
            id: 1,
            type: 'DAILY_LOGIN_GRANT',
            title: '合成登录赠送',
            delta: 100,
            balanceAfter: _balance,
            description: 'MOCK，仅内存',
            occurredAt: '2026-09-18T00:00:00Z',
          ),
        ],
      );
}

class _Store implements SessionStore {
  @override
  Future<AuthSession?> read() async => const AuthSession(
    accountId: 'mock-owner',
    phone: '13800000000',
    accessToken: 'not-a-real-credential',
  );
  @override
  Future<void> write(AuthSession session) async {}
  @override
  Future<void> clear() async {}
}
