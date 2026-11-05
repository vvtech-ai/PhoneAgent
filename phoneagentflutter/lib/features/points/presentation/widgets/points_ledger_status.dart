import 'package:flutter/material.dart';
import '../../../../core/design/auth_tokens.dart';

const ledgerRefreshErrorMessage = '网络连接异常，暂时无法更新积分流水，请检查网络后重试';

/// Native unavailable-ledger presentation; it never owns a request lifecycle.
class PointsLedgerStatus extends StatelessWidget {
  const PointsLedgerStatus({
    super.key,
    this.loading = false,
    this.centered = true,
    this.hasError = true,
    required this.message,
    required this.onRetry,
  });
  final bool loading, centered, hasError;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: loading
          ? Semantics(
              label: '正在同步积分流水',
              child: const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  color: AuthTokens.accent,
                ),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: hasError
                        ? const Color(0xFFD33A2C)
                        : const Color(0xFF8A8F98),
                  ),
                ),
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF276EF1),
                    padding: const EdgeInsets.all(12),
                    minimumSize: const Size(48, 48),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('重试'),
                ),
              ],
            ),
    );
    return centered
        ? Center(child: SingleChildScrollView(child: content))
        : content;
  }
}
