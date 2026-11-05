import 'package:flutter/material.dart';
import '../../../../core/design/native_page_header.dart';
import '../../../../core/design/shell_tokens.dart';
import '../../domain/points_presentation.dart';
import '../../domain/points_wallet.dart';
import '../controller/points_wallet_controller.dart';
import '../widgets/points_wallet_balance_card.dart';
import '../widgets/points_ledger_status.dart';

class PointsWalletPage extends StatelessWidget {
  const PointsWalletPage({
    super.key,
    required this.state,
    required this.onBack,
    required this.onLedger,
    required this.onRefresh,
    this.invitationContent,
    this.pointsPerMinute,
  });
  final Widget? invitationContent;
  final int? pointsPerMinute;
  final PointsWalletState state;
  final VoidCallback onBack, onLedger;
  final Future<void> Function() onRefresh;
  @override
  Widget build(BuildContext context) {
    final account = state.account;
    return PointsPageFrame(
      title: '积分',
      onBack: onBack,
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (account == null && state.loading)
              SizedBox(
                height: Theme.of(context).platform == TargetPlatform.iOS
                    ? 100
                    : 120,
                child: const Center(child: CircularProgressIndicator()),
              )
            else if (account == null)
              Center(
                child: _WalletError(
                  message: state.error.isEmpty ? '积分尚未同步，请联网后重试' : state.error,
                  onRetry: onRefresh,
                ),
              )
            else
              PointsWalletBalanceCard(
                state: state,
                onLedger: onLedger,
                pointsPerMinute: pointsPerMinute,
              ),
            if (invitationContent != null) invitationContent!,
          ],
        ),
      ),
    );
  }
}

class PointsLedgerPage extends StatelessWidget {
  const PointsLedgerPage({
    super.key,
    required this.state,
    required this.onBack,
    required this.onRefresh,
    required this.onLoadNext,
  });
  final PointsWalletState state;
  final VoidCallback onBack, onLoadNext;
  final Future<void> Function() onRefresh;
  @override
  Widget build(BuildContext context) => PointsPageFrame(
    title: '积分流水',
    onBack: onBack,
    child: !state.ledgerAvailable && state.items.isEmpty
        ? PointsLedgerStatus(
            loading: state.loading,
            hasError: state.error.isNotEmpty,
            message: state.error.isNotEmpty
                ? ledgerRefreshErrorMessage
                : '积分流水尚未同步，请刷新后查看最新明细',
            onRetry: onRefresh,
          )
        : RefreshIndicator(
            onRefresh: onRefresh,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: ColoredBox(
                  color: Colors.white,
                  child: ListView(
                    padding: EdgeInsets.only(
                      bottom: 24 + MediaQuery.viewPaddingOf(context).bottom,
                    ),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 18, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '收支明细',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF202124),
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              '展示账户全部积分收入与消耗',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF8A8F98),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (state.loading)
                        const LinearProgressIndicator(minHeight: 2),
                      if (state.error.isNotEmpty)
                        PointsLedgerStatus(
                          centered: false,
                          message: ledgerRefreshErrorMessage,
                          onRetry: onRefresh,
                        ),
                      if (state.ledgerStale)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            '积分流水尚未同步，请刷新后查看最新明细',
                            style: ShellTokens.subtitle,
                          ),
                        ),
                      if (state.items.isEmpty &&
                          !state.loading &&
                          !state.ledgerStale &&
                          state.error.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(36),
                          child: Text(
                            '暂无积分流水',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF8A8F98),
                            ),
                          ),
                        ),
                      for (final row in state.items.where(
                        (row) => row.delta != 0,
                      ))
                        _LedgerRow(row: row),
                      if (state.hasNext)
                        TextButton(
                          onPressed: state.loading || state.loadingNext
                              ? null
                              : onLoadNext,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF276EF1),
                            padding: const EdgeInsets.all(16),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          child: Text(state.loadingNext ? '加载中…' : '加载更多'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
  );
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.row});
  final PointsLedgerItem row;
  @override
  Widget build(BuildContext context) {
    final occurred = row.occurredAt.replaceAll('T', ' ');
    return Container(
      key: ValueKey('points-ledger-${row.id}'),
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      color: Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.title,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF202124),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  occurred.length > 16 ? occurred.substring(0, 16) : occurred,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8A8F98),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${row.description} · 操作后余额 ${PointsPresentation.balance(row.balanceAfter)}',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 17 / 12,
                    color: Color(0xFF8A8F98),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${row.delta > 0 ? '+' : ''}${row.delta}',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: row.delta > 0
                  ? const Color(0xFF08A357)
                  : const Color(0xFFE34242),
            ),
          ),
        ],
      ),
    );
  }
}

class PointsPageFrame extends StatelessWidget {
  const PointsPageFrame({
    super.key,
    required this.title,
    required this.onBack,
    required this.child,
  });
  final String title;
  final VoidCallback onBack;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      NativePageHeader(title: title, onBack: onBack),
      Expanded(child: child),
    ],
  );
}

class _WalletError extends StatelessWidget {
  const _WalletError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFD33A2C), fontSize: 13),
        ),
        TextButton(onPressed: onRetry, child: const Text('重试')),
      ],
    ),
  );
}
