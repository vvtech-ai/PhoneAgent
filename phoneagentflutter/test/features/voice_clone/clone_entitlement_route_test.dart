import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/clone_flow_providers.dart';
import 'package:phone_agent/app/commerce_providers.dart';
import 'package:phone_agent/app/points_providers.dart';
import 'package:phone_agent/features/points/domain/points_wallet_cache.dart';
import 'package:phone_agent/features/commerce/presentation/pages/membership_route.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_creation.dart';
import 'package:phone_agent/features/voice_clone/presentation/pages/clone_creation_route.dart';
import '../commerce/fake_commerce_repository.dart';
import '../commerce/membership_route_v2_test.dart' show V2Wallet;

class _Port implements CloneCreationPort {
  bool? entitled = false;
  String reason = '';
  int reads = 0, points = 0, recordings = 0;
  Completer<List<CloneCreationModel>>? pending;
  bool mixed = false;
  bool fail = false;
  @override
  Future<List<CloneCreationModel>> models() async {
    reads++;
    if (fail) throw CloneCatalogFailure.network;
    return pending?.future ??
        [
          CloneCreationModel(
            id: 'qwen',
            name: 'Qwen',
            pricePoints: 300,
            cloneEntitled: entitled,
            entitlementReason: reason,
          ),
          if (mixed)
            const CloneCreationModel(
              id: 'doubao',
              name: 'Doubao',
              pricePoints: 300,
              cloneEntitled: true,
            ),
        ];
  }

  @override
  Future<int> availablePoints() async {
    points++;
    return 900;
  }

  @override
  Future<bool> hasValidRecording() async {
    recordings++;
    return false;
  }
}

Future<ProviderContainer> _open(
  WidgetTester tester,
  _Port port, {
  StateProvider<int?>? epoch,
}) async {
  final container = ProviderContainer(
    overrides: [
      loginEpochProvider.overrideWith(
        (ref) => epoch == null ? 1 : ref.watch(epoch),
      ),
      cloneCreationPortProvider.overrideWithValue(port),
      commerceRepositoryProvider.overrideWithValue(FakeCommerceRepository()),
      paymentLauncherProvider.overrideWithValue(FakePaymentLauncher()),
      pointsWalletRepositoryProvider.overrideWithValue(V2Wallet()),
      pointsWalletCacheProvider.overrideWithValue(
        const EmptyPointsWalletCache(),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => openCloneCreation(context),
              child: const Text('来源页'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('来源页'));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets(
    'account change while upgrading cannot refresh or enter the old clone flow',
    (tester) async {
      final port = _Port();
      final epoch = StateProvider<int?>((ref) => 1);
      final container = await _open(tester, port, epoch: epoch);
      await tester.tap(find.text('查看会员权益'));
      await tester.pumpAndSettle();
      container.read(epoch.notifier).state = 2;
      port.entitled = true;
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(port.reads, 1);
      expect(find.text('开始认证'), findsNothing);
      expect(port.points, 0);
      expect(port.recordings, 0);
    },
  );

  testWidgets(
    'lookup failure retries without reporting denial or reading identity',
    (tester) async {
      final port = _Port()..fail = true;
      await _open(tester, port);
      expect(find.text('暂无声音克隆权益'), findsNothing);
      expect(find.text(CloneCatalogFailure.network.message), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
      port.fail = false;
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.text('暂无声音克隆权益'), findsOneWidget);
      expect(port.points, 0);
      expect(port.recordings, 0);
    },
  );

  testWidgets('return without upgrade checks again and still blocks creation', (
    tester,
  ) async {
    final port = _Port();
    await _open(tester, port);
    await tester.tap(find.text('查看会员权益'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(port.reads, 2);
    expect(find.text('暂无声音克隆权益'), findsOneWidget);
    expect(find.text('开始认证'), findsNothing);
    expect(port.points, 0);
    expect(port.recordings, 0);
  });

  testWidgets('upgrade opens membership and returning reloads entitlement', (
    tester,
  ) async {
    final port = _Port();
    await _open(tester, port);
    await tester.tap(find.text('查看会员权益'));
    await tester.pumpAndSettle();
    expect(find.byType(MembershipRoute), findsOneWidget);
    expect(port.reads, 1);
    port.entitled = true;
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(port.reads, 2);
    expect(find.text('选择声音克隆模型'), findsOneWidget);
    expect(find.text('暂无声音克隆权益'), findsNothing);
    expect(find.text('开始认证'), findsNothing);
    expect(port.points, 0);
  });

  testWidgets(
    'all denied prompts before model selection and cancel preserves source',
    (tester) async {
      final port = _Port();
      await _open(tester, port);
      expect(find.text('暂无声音克隆权益'), findsOneWidget);
      expect(find.text('当前会员暂不支持声音克隆，可前往会员页查看各等级权益。'), findsOneWidget);
      expect(find.text('选择声音克隆模型'), findsNothing);
      expect(find.text('开始认证'), findsNothing);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.byType(CloneCreationRoute), findsNothing);
      expect(find.text('来源页'), findsOneWidget);
      expect(port.points, 0);
      expect(port.recordings, 0);
    },
  );

  testWidgets('mixed models check selected model before authentication', (
    tester,
  ) async {
    final port = _Port()..mixed = true;
    await _open(tester, port);
    expect(find.text('选择声音克隆模型'), findsOneWidget);
    await tester.tap(find.text('Qwen'));
    await tester.pumpAndSettle();
    expect(find.text('暂无声音克隆权益'), findsOneWidget);
    expect(port.points, 0);
    expect(port.recordings, 0);
  });

  testWidgets('legacy unknown shows retry and reloads current entitlement', (
    tester,
  ) async {
    final port = _Port()..entitled = null;
    await _open(tester, port);
    expect(find.text('暂无声音克隆权益'), findsNothing);
    expect(find.text('声音克隆权益读取失败，请重试'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    port.entitled = true;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(port.reads, 2);
    expect(find.text('选择声音克隆模型'), findsOneWidget);
    expect(find.text('开始认证'), findsNothing);
  });
}
