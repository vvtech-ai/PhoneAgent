import 'session_exit_loading_host.dart';
import '../core/design/native_page_background.dart';
import '../features/account_cancellation/presentation/cancellation_exit_host.dart';
import '../features/account_cancellation/presentation/cancellation_providers.dart';
import '../features/auth/presentation/controller/session_controller.dart';
import '../core/design/native_system_chrome.dart';
import '../core/design/page_route_visibility.dart';
import '../features/invite/presentation/widgets/invite_reward_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/design/auth_tokens.dart';
import '../features/auth/presentation/pages/auth_route.dart';
import 'mobile_preview.dart';
import 'commerce_providers.dart';
import 'apple_transaction_providers.dart';
import 'business_providers.dart' show loginEpochProvider;
import '../features/auth/presentation/controller/auth_providers.dart';
import 'session_navigation_host.dart';
import 'task_draft_cleanup_providers.dart';
import 'trusted_caller_account_providers.dart';
import 'trusted_incoming_identity_providers.dart';
import '../features/trusted_caller/presentation/widgets/trusted_identity_presentation_host.dart';

export 'app_providers.dart' show appConfigProvider;

final pageRouteVisibilityProvider = Provider<PageRouteVisibilityObserver>((
  ref,
) {
  ref.watch(loginEpochProvider);
  ref.watch(
    sessionControllerProvider.select(
      (s) => s.businessBlocked && s.invalidationReason != null,
    ),
  );
  final observer = PageRouteVisibilityObserver();
  ref.onDispose(observer.dispose);
  return observer;
});

final appRouterProvider = Provider<GoRouter>((ref) {
  // Imperative routes belong to one login, not just the root AuthRoute widget.
  // Token refresh retains the epoch and therefore keeps navigation and drafts.
  ref.watch(loginEpochProvider);
  // Forced expiry removes old modals before secure-store cleanup; own cancellation keeps its owner.
  ref.watch(
    sessionControllerProvider.select(
      (s) => s.businessBlocked && s.invalidationReason != null,
    ),
  );
  final router = GoRouter(
    observers: [ref.watch(pageRouteVisibilityProvider)],
    routes: [
      GoRoute(path: '/', builder: (context, state) => const AuthRoute()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class PhoneAgentApp extends ConsumerWidget {
  const PhoneAgentApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(trustedCallerAccountSyncProvider);
    ref.watch(iosCommerceRecoveryProvider);
    ref.watch(appleTransactionCoordinatorProvider);
    final epoch = ref.watch(loginEpochProvider);
    final sessionState = ref.watch(sessionControllerProvider);
    final cancellationExit = ref.watch(cancellationExitControllerProvider);
    final session = ref.watch(sessionControllerProvider.notifier);
    final draftStore = ref.watch(taskDraftAccountStoreProvider);
    final router = ref.watch(appRouterProvider);
    final pageVisibility = ref.watch(pageRouteVisibilityProvider);
    final identity = ref.watch(trustedIdentitySurfaceControllerProvider);
    final presentationDiagnostics = ref.watch(
      trustedIncomingPresentationDiagnosticsProvider,
    );
    return MaterialApp.router(
      title: 'PhoneAgent',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final navigation = SessionNavigationHost(
          session: session,
          epoch: epoch,
          onReleased: draftStore?.clearAccount,
          releasePlaceholder: cancellationExit.visible
              ? const ColoredBox(color: Colors.white)
              : sessionState.businessBlocked &&
                    sessionState.invalidationReason != null
              ? const NativePageBackground(child: SizedBox.expand())
              : null,
          child: TrustedIdentityPresentationHost(
            navigatorKey: router.routerDelegate.navigatorKey,
            identity: identity,
            onDiagnostic: presentationDiagnostics,
            onDismiss: (eventId) => ref
                .read(trustedIncomingIdentityControllerProvider.notifier)
                .dismiss(eventId),
            child: InviteEntryHost(
              navigatorKey: router.routerDelegate.navigatorKey,
              child: child!,
            ),
          ),
        );
        final transition = SessionExitLoadingHost(
          owner: session,
          session: sessionState,
          epoch: epoch,
          cleaning: session.invalidationCleanupRunning,
          child: CancellationExitHost(
            controller: cancellationExit,
            signedOut: sessionState.phase == SessionPhase.signedOut,
            child: navigation,
          ),
        );
        return PageRouteVisibilityScope(
          observer: pageVisibility,
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: NativeSystemChrome.light,
            child: TooltipVisibility(
              visible: false,
              child: kIsWeb ? MobilePreview(child: transition) : transition,
            ),
          ),
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AuthTokens.accent,
        ).copyWith(primary: AuthTokens.accent),
      ),
      routerConfig: router,
    );
  }
}
