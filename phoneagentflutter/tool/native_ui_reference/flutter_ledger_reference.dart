import 'package:flutter/material.dart';
import 'package:phone_agent/features/points/domain/points_wallet.dart'
    show PointsLedgerItem;
import 'package:phone_agent/features/points/presentation/controller/points_wallet_controller.dart';
import 'package:phone_agent/features/points/presentation/pages/points_wallet_page.dart';

/// Matching native synthetic ledger scenes; no repositories or business ports.
class FlutterLedgerReference extends StatelessWidget {
  const FlutterLedgerReference({super.key, required this.scene});
  final String scene;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF6F7F9),
    body: SafeArea(
      bottom: false,
      child: PointsLedgerPage(
        state: PointsWalletState(
          ledgerAvailable: scene == 'ledger' || scene == 'ledger-empty',
          // Production PointsWalletController already projects out zero deltas.
          items: scene == 'ledger'
              ? _items.where((item) => item.delta != 0).toList(growable: false)
              : const [],
          loading: scene == 'ledger-loading',
          error: scene == 'ledger-error' ? '网络连接异常，暂时无法更新积分流水，请检查网络后重试' : '',
          hasNext: scene == 'ledger',
        ),
        onBack: () {},
        onRefresh: () async {},
        onLoadNext: () {},
      ),
    ),
  );
}

const _items = [
  PointsLedgerItem(
    id: 1,
    type: 'DAILY_GRANT',
    title: '每日登录赠送',
    delta: 100,
    balanceAfter: 900,
    description: '每日登录赠送',
    occurredAt: '2026-09-20T09:00:00',
  ),
  PointsLedgerItem(
    id: 2,
    type: 'CALL',
    title: '通话扣费',
    delta: -20,
    balanceAfter: 880,
    description: '合成通话1分钟',
    occurredAt: '2026-09-20T09:01:00',
  ),
  PointsLedgerItem(
    id: 3,
    type: 'SYNTHETIC_ZERO',
    title: '合成零变更',
    delta: 0,
    balanceAfter: 880,
    description: '无积分变更',
    occurredAt: '2026-09-20T09:02:00',
  ),
];
