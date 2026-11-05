import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../controller/identity_controller.dart';
import 'identity_widgets.dart';

/// Initial load states and cached native hint cards share no data lifecycle.
class IdentityStatusContent extends StatelessWidget {
  const IdentityStatusContent({
    super.key,
    required this.state,
    required this.onRetry,
    this.onRetryCleanup,
  });
  final IdentityState state;
  final VoidCallback onRetry;
  final VoidCallback? onRetryCleanup;

  @override
  Widget build(BuildContext context) {
    if (state.initialLoadStatus) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 72),
          if (state.operation == IdentityOperation.loading) ...[
            const CupertinoActivityIndicator(color: IdentityStyle.muted),
            const SizedBox(height: 14),
            const Text(
              '正在加载身份信息…',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: IdentityStyle.muted),
            ),
          ] else ...[
            const Text(
              '身份信息加载失败',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Semantics(
              liveRegion: true,
              child: Text(
                state.error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: IdentityStyle.danger,
                ),
              ),
            ),
            const SizedBox(height: 24),
            IdentityAction(label: '重试', onTap: state.busy ? null : onRetry),
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.busy && !state.editing) ...[
          _HintCard(
            text: state.operation == IdentityOperation.cleaning
                ? '正在重试本地处理…'
                : state.operation == IdentityOperation.deleting
                ? '正在删除身份…'
                : '正在加载身份信息…',
          ),
          const SizedBox(height: 10),
        ],
        if (state.error.isNotEmpty) ...[
          _HintCard(
            text: state.error,
            danger: true,
            showRetry: state.loadFailed || state.profile == null,
            onRetry: state.busy ? null : onRetry,
          ),
          if (state.cleanupPending)
            TextButton(
              onPressed: state.busy ? null : onRetryCleanup,
              child: const Text('重试本地处理'),
            ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({
    required this.text,
    this.danger = false,
    this.showRetry = false,
    this.onRetry,
  });
  final String text;
  final bool danger, showRetry;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: danger ? const Color(0x1FE14D46) : const Color(0xFFF7F8FA),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  height: 19 / 13,
                  color: danger ? IdentityStyle.danger : IdentityStyle.ink,
                ),
              ),
            ),
          ),
          if (showRetry) ...[
            const SizedBox(width: 10),
            TextButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ],
      ),
    ),
  );
}
