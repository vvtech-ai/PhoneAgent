import 'package:flutter/material.dart';
import '../../../../core/design/shell_tokens.dart';
import '../../domain/points_presentation.dart';
import '../controller/points_wallet_controller.dart';

/// Native balance presentation; all data and actions remain with the caller.
class PointsWalletBalanceCard extends StatelessWidget {
  const PointsWalletBalanceCard({
    super.key,
    required this.state,
    required this.onLedger,
    this.pointsPerMinute,
  });
  final PointsWalletState state;
  final int? pointsPerMinute;
  final VoidCallback onLedger;

  @override
  Widget build(BuildContext context) {
    final account = state.account;
    if (account == null) return const SizedBox.shrink();
    final minutes = PointsPresentation.estimatedMinutes(
      account.availableBalance,
      pointsPerMinute: pointsPerMinute,
    );
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.stale)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                '当前显示上次同步数据，非最新余额',
                style: TextStyle(color: Color(0xFFF29900), fontSize: 12),
              ),
            ),
          if (!state.stale && state.ledgerStale)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text('余额已更新，积分流水待刷新', style: ShellTokens.subtitle),
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              final balance = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '当前可用积分',
                    style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Text(
                        '✦',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFFC400),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Flexible(
                        child: Text(
                          PointsPresentation.balance(account.availableBalance),
                          style: const TextStyle(
                            fontSize: 32,
                            height: 43 / 32,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111111),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
              final ledger = TextButton(
                onPressed: onLedger,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF5F636B),
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(48, 48),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('积分流水  ›'),
              );
              if (MediaQuery.textScalerOf(context).scale(14) > 21 ||
                  constraints.maxWidth < 260) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    balance,
                    Align(alignment: Alignment.centerRight, child: ledger),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: balance),
                  ledger,
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            '${minutes == null ? '通话时长估算暂不可用' : '约可通话 $minutes 分钟'}'
            '${account.todayDailyGrantPoints > 0 ? ' · 今日赠送${account.todayDailyGrantPoints}积分已到账' : ''}',
            style: const TextStyle(
              fontSize: 12,
              height: 17 / 12,
              color: Color(0xFF8A8F98),
            ),
          ),
        ],
      ),
    );
  }
}
