import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design/native_business_dialog.dart';
import '../../auth/presentation/controller/auth_providers.dart';
import '../domain/account_cancellation.dart';

class CancellationLoginHost extends ConsumerStatefulWidget {
  const CancellationLoginHost({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<CancellationLoginHost> createState() =>
      _CancellationLoginHostState();
}

class _CancellationLoginHostState extends ConsumerState<CancellationLoginHost> {
  String? _shown;
  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(
      authControllerProvider.select((s) => s.cancellation),
    );
    if (pending != null && pending.challenge != _shown) {
      _shown = pending.challenge;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _show(pending);
      });
    }
    return widget.child;
  }

  Future<void> _show(CancellationPendingLogin pending) async {
    var dialogOpen = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Consumer(
        builder: (_, ref, __) {
          final state = ref.watch(authControllerProvider);
          ref.listen(authControllerProvider.select((s) => s.cancellation), (
            _,
            next,
          ) {
            if (next == null &&
                dialogOpen &&
                dialogContext.mounted &&
                ModalRoute.of(dialogContext)?.isCurrent == true) {
              Navigator.of(dialogContext).pop();
            }
          });
          return NativeBusinessDialog(
            title: '账号正在注销中',
            message:
                '你已提交账号注销，将于 ${cancellationTime(pending.effectiveAt)} 正式注销。'
                '若继续登录，注销流程将自动终止。',
            error: state.notice,
            allowBack: !state.working,
            dismissLabel: '保持注销',
            dismissBackgroundColor: const Color(0xFFF2F4F7),
            dismissForegroundColor: const Color(0xFFE14D46),
            onDismiss: state.working
                ? null
                : () => Navigator.of(dialogContext).pop(),
            confirmLabel: state.working ? '处理中…' : '继续登录',
            confirmBackgroundColor: const Color(0xFF111111),
            confirmForegroundColor: Colors.white,
            onConfirm: state.working
                ? null
                : ref
                      .read(authControllerProvider.notifier)
                      .continueCancellation,
          );
        },
      ),
    );
    dialogOpen = false;
    if (mounted) ref.read(authControllerProvider.notifier).keepCancellation();
  }
}
