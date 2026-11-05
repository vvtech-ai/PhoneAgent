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
  final observer = PageRouteVisibilityObserver();
  ref.onDispose(observer.dispose);
  return observer;
});

final appRouterProvider = Provider<GoRouter>((ref) {
  // Imperative routes belong to one login, not just the root AuthRoute widget.
  // Token refresh retains the epoch and therefore keeps navigation and drafts.
  ref.watch(loginEpochProvider);
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
    final epoch = ref.watch(loginEpochProvider);
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
        return PageRouteVisibilityScope(
          observer: pageVisibility,
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: NativeSystemChrome.light,
            child: kIsWeb ? MobilePreview(child: navigation) : navigation,
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
