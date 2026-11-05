import 'invite_reward_card.dart';
import '../../../../core/design/native_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/invite_providers.dart';
import '../../../auth/presentation/controller/auth_providers.dart';

class InviteRewardHost extends ConsumerWidget {
  const InviteRewardHost({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inviteRewardProvider);
    final reward = state.reward;
    return PopScope(
      canPop: reward == null,
      child: Stack(
        children: [
          child,
          if (reward == null && state.error.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(child: Text(state.error)),
                        TextButton(
                          onPressed: () => ref
                              .read(inviteRewardProvider.notifier)
                              .initialize(
                                ref
                                    .read(sessionControllerProvider)
                                    .loginOutcome,
                              ),
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (reward != null) ...[
            const Positioned.fill(
              child: ModalBarrier(dismissible: false, color: Colors.black38),
            ),
            Center(
              child: InviteRewardCard(
                amount: reward.amount,
                error: state.error,
                onConfirm: state.busy
                    ? null
                    : () {
                        ref.read(inviteRewardProvider.notifier).acknowledge();
                      },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class InviteEntryHost extends ConsumerWidget {
  const InviteEntryHost({
    required this.child,
    required this.navigatorKey,
    super.key,
  });
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(inviteEntryProvider);
    ref.listen(inviteEntryProvider, (_, notice) {
      if (notice.isEmpty) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final overlay = navigatorKey.currentState?.overlay;
        if (context.mounted && overlay != null && overlay.mounted) {
          showNativeNotice(
            context,
            notice,
            overlay: overlay,
            duration: const Duration(seconds: 4),
          );
        }
      });
    });
    return child;
  }
}
