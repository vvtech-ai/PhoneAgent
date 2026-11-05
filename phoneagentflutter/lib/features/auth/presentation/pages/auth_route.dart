import '../../../../core/network/account_session.dart';
import '../../../account_cancellation/presentation/cancellation_login_host.dart';
import '../../../account_cancellation/presentation/cancellation_providers.dart';
import '../../../../app/invite_registration_providers.dart';
import '../../../../app/initialization_providers.dart';
import '../../../invite/presentation/pages/invite_welcome_page.dart';
import '../../../invite/presentation/widgets/invite_reward_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shell/presentation/pages/shell_route.dart';
import '../../../points/presentation/widgets/points_session_host.dart';
import '../../../app_update/presentation/widgets/startup_update_host.dart';
import '../controller/auth_providers.dart';
import '../controller/legal_document_providers.dart';
import '../controller/session_controller.dart';
import 'auth_page.dart';
import '../widgets/startup_page.dart';
import '../../../../core/design/native_notice.dart';

class AuthRoute extends ConsumerWidget {
  const AuthRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    if (session.phase == SessionPhase.restoring) {
      return const StartupPage();
    }
    if (session.phase == SessionPhase.restoreFailed) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('无法读取登录状态，请重试'),
                TextButton(
                  onPressed: ref
                      .read(sessionControllerProvider.notifier)
                      .restore,
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (session.businessBlocked) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                session.invalidationReason == null
                    ? '注销申请已受理，请完成退出登录'
                    : '登录状态已失效，请完成退出登录',
              ),
              TextButton(
                onPressed:
                    ref
                        .read(sessionControllerProvider.notifier)
                        .invalidationCleanupRunning
                    ? null
                    : () async {
                        if (session.invalidationReason != null) {
                          await ref
                              .read(sessionControllerProvider.notifier)
                              .retryInvalidation();
                          return;
                        }
                        final exit = ref.read(
                          cancellationExitControllerProvider,
                        );
                        final token = exit.retryCleanup();
                        try {
                          await ref
                              .read(sessionControllerProvider.notifier)
                              .signOut();
                        } catch (_) {
                          if (token != null) exit.fail(token);
                        }
                      },
                child: const Text('重试退出'),
              ),
            ],
          ),
        ),
      );
    }
    if (session.phase == SessionPhase.signedIn) {
      ref.listen(initializationModelSwitchProvider, (_, notice) {
        if (notice.isNotEmpty) showNativeNotice(context, notice);
      });
      return StartupUpdateHost(
        key: ValueKey(
          ref.read(sessionControllerProvider.notifier).credentials?.epoch,
        ),
        child: const InviteRewardHost(
          child: PointsSessionHost(child: ShellRoute()),
        ),
      );
    }
    ref.listen(authControllerProvider.select((state) => state.notice), (
      _,
      notice,
    ) {
      if (notice.isEmpty) return;
      showNativeNotice(context, notice);
    });
    final submitted = ref.watch(cancellationSubmittedNoticeProvider);
    if (submitted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted ||
            ref.read(sessionControllerProvider).phase !=
                SessionPhase.signedOut ||
            !ref.read(cancellationSubmittedNoticeProvider)) {
          return;
        }
        ref.read(cancellationSubmittedNoticeProvider.notifier).state = false;
        showNativeNotice(
          context,
          '已提交注销申请',
          centered: true,
          duration: const Duration(seconds: 2),
        );
      });
    }
    if (session.invalidationReason != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final reason = ref
            .read(sessionControllerProvider.notifier)
            .takeInvalidationNotice();
        if (reason == null || ref.read(cancellationSubmittedNoticeProvider)) {
          return;
        }
        showNativeNotice(context, switch (reason) {
          SessionInvalidationReason.cancellationPending => '账号正在注销中，已退出登录',
          SessionInvalidationReason.cancelled => '账号已注销，已退出登录',
          SessionInvalidationReason.revoked ||
          SessionInvalidationReason.expired => '登录状态已失效，请重新登录',
        });
      });
    }
    final auth = ref.watch(authControllerProvider);
    final pending = ref.watch(pendingInviteProvider);
    final activationTakesPriority =
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        auth.invitation;
    if (pending.welcome && !activationTakesPriority) {
      return InviteWelcomePage(code: pending.code, entryId: pending.entryId);
    }
    final controller = ref.read(authControllerProvider.notifier);
    return CancellationLoginHost(
      child: AuthPage(
        state: auth,
        actions: AuthActions(
          phone: controller.changePhone,
          code: controller.changeCode,
          invite: controller.changeInvite,
          sendCode: controller.sendCode,
          submit: controller.submit,
          back: controller.backToLogin,
          openDocument: (document) async {
            try {
              await ref.read(legalDocumentPortProvider).open(document);
            } catch (_) {
              if (!context.mounted) return;
              showNativeNotice(context, '暂时无法打开协议，请稍后重试');
            }
          },
        ),
      ),
    );
  }
}
