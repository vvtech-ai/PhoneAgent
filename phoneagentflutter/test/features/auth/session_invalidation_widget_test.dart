import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/session_navigation_host.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/auth/presentation/controller/session_controller.dart';
import 'package:phone_agent/features/auth/presentation/pages/auth_route.dart';
import '../../support/local_storage_channel_fake.dart';
import 'session_invalidation_test.dart' show Store, login;

void main() {
  testWidgets(
    'old modal removed, original login shown, one expiry prompt consumed',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      installLocalStorageChannelFake();
      final store = Store();
      final session = SessionController(store);
      await session.accept(login);
      final container = ProviderContainer(
        overrides: [
          sessionControllerProvider.overrideWith((_) => session),
          sessionStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              final state = ref.watch(sessionControllerProvider);
              return MaterialApp(
                key: ValueKey((
                  session.identityEpoch,
                  state.businessBlocked && state.invalidationReason != null,
                )),
                builder: (_, child) => SessionNavigationHost(
                  session: session,
                  epoch: session.identityEpoch,
                  child: child!,
                ),
                home:
                    state.businessBlocked ||
                        state.phase == SessionPhase.signedOut
                    ? const AuthRoute()
                    : Builder(
                        builder: (context) => Scaffold(
                          body: TextButton(
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (_) =>
                                  const AlertDialog(content: Text('旧账号确认框')),
                            ),
                            child: const Text('打开'),
                          ),
                        ),
                      ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      final owner = session.credentials!;
      store.clearGate = Completer<void>();
      final invalidation = session.invalidateSession(
        owner,
        SessionInvalidationReason.cancellationPending,
      );
      await tester.pumpAndSettle();
      expect(find.text('旧账号确认框'), findsNothing);
      expect(find.text('登录状态已失效，请完成退出登录'), findsOneWidget);
      expect(find.text('账号正在注销中，已退出登录'), findsNothing);
      store.clearGate!.complete();
      await tester.pumpAndSettle();
      await invalidation;
      await tester.pumpAndSettle();
      expect(find.text('旧账号确认框'), findsNothing);
      expect(find.byKey(const ValueKey('loginPhone')), findsOneWidget);
      expect(find.text('账号正在注销中，已退出登录'), findsOneWidget);
      await session.invalidateSession(
        owner,
        SessionInvalidationReason.cancellationPending,
      );
      await tester.pump();
      expect(store.clears, 1);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('账号正在注销中，已退出登录'), findsNothing);
      await tester.pump();
      expect(find.text('账号正在注销中，已退出登录'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
