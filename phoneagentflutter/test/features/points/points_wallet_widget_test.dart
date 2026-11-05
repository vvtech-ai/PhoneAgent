import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/points_providers.dart';
import 'package:phone_agent/features/points/domain/points_presentation.dart';
import 'package:phone_agent/features/points/domain/points_wallet.dart'
    as domain;
import 'package:phone_agent/features/points/presentation/controller/points_wallet_controller.dart';
import 'package:phone_agent/features/points/presentation/pages/points_wallet_page.dart';
import 'package:phone_agent/features/points/presentation/pages/points_wallet_route.dart';
import 'package:phone_agent/features/points/presentation/widgets/points_balance_badge.dart';

const account = domain.PointsAccount(
  totalBalance: 2000,
  availableBalance: 1234,
  heldBalance: 766,
  updatedAt: '',
  todayDailyGrantPoints: 100,
);
void main() {
  testWidgets('updated balance and stale ledger are explained separately', (
    tester,
  ) async {
    const state = PointsWalletState(account: account, ledgerStale: true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PointsWalletPage(
            pointsPerMinute: 100,
            state: state,
            onBack: () {},
            onLedger: () {},
            onRefresh: () async {},
          ),
        ),
      ),
    );
    expect(find.text('1,234'), findsOneWidget);
    expect(find.text('余额已更新，积分流水待刷新'), findsOneWidget);
    expect(find.textContaining('非最新余额'), findsNothing);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PointsLedgerPage(
            state: state,
            onBack: () {},
            onLoadNext: () {},
            onRefresh: () async {},
          ),
        ),
      ),
    );
    expect(find.text('积分流水尚未同步，请刷新后查看最新明细'), findsOneWidget);
    expect(find.text('暂无积分流水'), findsNothing);
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'wallet order and ledger actions survive narrow screen at $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var opened = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: PointsWalletPage(
                  pointsPerMinute: 100,
                  state: const PointsWalletState(account: account),
                  onBack: () {},
                  onLedger: () => opened++,
                  onRefresh: () async {},
                  invitationContent: const Text('邀请好友，领取积分'),
                ),
              ),
            ),
          ),
        );
        if (scale == 1) {
          expect(
            tester.getTopLeft(find.text('当前可用积分')).dy,
            lessThan(tester.getTopLeft(find.text('邀请好友，领取积分')).dy),
          );
        }
        await tester.ensureVisible(find.text('积分流水  ›'));
        await tester.tap(find.text('积分流水  ›'));
        expect(opened, 1);
        await tester.scrollUntilVisible(find.text('邀请好友，领取积分'), 160);
        expect(find.text('邀请好友，领取积分'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  test('unknown is not zero; formatting and v65 estimated minutes', () {
    expect(PointsPresentation.balance(null), '--');
    expect(PointsPresentation.balance(-1), '0');
    expect(PointsPresentation.balance(1234567), '1,234,567');
    expect(PointsPresentation.estimatedMinutes(1234, pointsPerMinute: 100), 12);
  });
  testWidgets('wallet known balance, stale/error retry and ledger action', (
    tester,
  ) async {
    var ledger = 0, retry = 0;
    Future<void> render(PointsWalletState state) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PointsWalletPage(
            pointsPerMinute: 100,
            state: state,
            onBack: () {},
            onLedger: () => ledger++,
            onRefresh: () async {
              retry++;
            },
          ),
        ),
      ),
    );
    await render(const PointsWalletState(loading: true));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('0'), findsNothing);
    await render(const PointsWalletState(error: '积分加载失败，请重试'));
    expect(find.text('当前可用积分'), findsNothing);
    await tester.tap(find.text('重试'));
    expect(retry, 1);
    await render(const PointsWalletState(account: account, stale: true));
    await tester.pumpAndSettle();
    expect(find.text('1,234'), findsOneWidget);
    expect(find.textContaining('12 分钟'), findsOneWidget);
    expect(find.textContaining('今日赠送100积分'), findsOneWidget);
    expect(find.textContaining('非最新余额'), findsOneWidget);
    await tester.tap(find.text('积分流水  ›'));
    expect(ledger, 1);
    expect(find.textContaining('充值'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('ledger empty / signed rows / paging disable / back', (
    tester,
  ) async {
    var next = 0, back = 0;
    Future<void> render(PointsWalletState state) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PointsLedgerPage(
            state: state,
            onBack: () => back++,
            onRefresh: () async {},
            onLoadNext: () => next++,
          ),
        ),
      ),
    );
    await render(const PointsWalletState(ledgerAvailable: true));
    expect(find.text('暂无积分流水'), findsOneWidget);
    await render(
      PointsWalletState(items: [_item(1, 100), _item(2, -20)], hasNext: true),
    );
    expect(find.text('+100'), findsOneWidget);
    expect(find.text('-20'), findsOneWidget);
    expect(find.text('2026-09-17 09:00'), findsNWidgets(2));
    await tester.tap(find.text('加载更多'));
    expect(next, 1);
    await render(
      PointsWalletState(
        items: [_item(1, 100)],
        hasNext: true,
        loadingNext: true,
      ),
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '加载中…'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byTooltip('返回'));
    expect(back, 1);
  });
  testWidgets(
    'badge to wallet to ledger and back shares one wallet state at 390px',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _Repository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [pointsWalletRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: PointsBalanceBadge(
                  balance: 1234,
                  onOpen: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => const PointsWalletRoute(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('open-points-wallet')));
      await tester.pumpAndSettle();
      expect(find.text('当前可用积分'), findsOneWidget);
      await tester.tap(find.text('积分流水  ›'));
      await tester.pumpAndSettle();
      expect(find.text('+100'), findsOneWidget);
      expect(repo.accounts, 1);
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(find.text('当前可用积分'), findsOneWidget);
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('open-points-wallet')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

domain.PointsLedgerItem _item(int id, int delta) => domain.PointsLedgerItem(
  id: id,
  type: 'SYNTHETIC',
  title: '合成流水',
  delta: delta,
  balanceAfter: 1234,
  description: '测试',
  occurredAt: '2026-09-17T09:00:00Z',
);

class _Repository implements domain.PointsWalletRepository {
  int accounts = 0;
  @override
  Future<domain.PointsAccount> account() async {
    accounts++;
    return const domain.PointsAccount(
      totalBalance: 1234,
      availableBalance: 1234,
      heldBalance: 0,
      updatedAt: '',
    );
  }

  @override
  Future<domain.PointsLedgerPage> ledger(int page, {int size = 20}) async =>
      domain.PointsLedgerPage(
        items: [_item(1, 100)],
        page: 0,
        size: 20,
        totalElements: 1,
        totalPages: 1,
      );
}
