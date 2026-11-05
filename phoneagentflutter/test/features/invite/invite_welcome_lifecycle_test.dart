import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/invite_registration_providers.dart';
import 'package:phone_agent/features/auth/data/unavailable_auth_gateway.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_controller.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/invite/domain/invite.dart';
import 'package:phone_agent/features/invite/domain/invite_store.dart';
import 'package:phone_agent/features/invite/presentation/controller/pending_invite_controller.dart';
import 'package:phone_agent/features/invite/presentation/pages/invite_welcome_page.dart';

class _Resolver implements InviteResolver {
  int calls = 0;
  @override
  Future<int> resolve(String code) async {
    calls++;
    return 20;
  }
}

class _DelayedResolver implements InviteResolver {
  final codes = <String>[];
  final requests = <Completer<int>>[];
  @override
  Future<int> resolve(String code) {
    codes.add(code);
    final request = Completer<int>();
    requests.add(request);
    return request.future;
  }
}

void main() {
  testWidgets(
    'new entry with same code isolates previous slow welcome response',
    (tester) async {
      final resolver = _DelayedResolver();
      final current = ValueNotifier<InviteWelcomeEntry>((
        code: 'ABCD',
        entryId: 1,
      ));
      addTearDown(current.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [inviteResolverProvider.overrideWithValue(resolver)],
          child: MaterialApp(
            home: ValueListenableBuilder<InviteWelcomeEntry>(
              valueListenable: current,
              builder: (_, entry, __) =>
                  InviteWelcomePage(code: entry.code, entryId: entry.entryId),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(resolver.codes, ['ABCD']);
      current.value = (code: 'ABCD', entryId: 2);
      await tester.pump();
      await tester.pump();
      expect(resolver.codes, ['ABCD', 'ABCD']);
      resolver.requests.first.complete(100);
      await tester.pump();
      expect(find.text('100'), findsNothing);
      resolver.requests[1].complete(200);
      await tester.pumpAndSettle();
      expect(find.text('200'), findsOneWidget);
      current.value = (code: 'EFGH', entryId: 3);
      await tester.pump();
      expect(find.text('200'), findsNothing);
      expect(find.text('EFGH'), findsOneWidget);
      resolver.requests[2].complete(300);
      await tester.pumpAndSettle();
      expect(find.text('300'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('foreground refresh and system back retain pending referral', (
    tester,
  ) async {
    final pending = PendingInviteController(MemoryInviteStore());
    await pending.receive('ABCD');
    final resolver = _Resolver();
    final auth = AuthController(
      const UnavailableAuthGateway(),
      pendingInvite: pending,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pendingInviteProvider.overrideWith((ref) => pending),
          inviteResolverProvider.overrideWithValue(resolver),
          authControllerProvider.overrideWith((ref) => auth),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              ref.watch(authControllerProvider);
              return const InviteWelcomePage(code: 'ABCD');
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(resolver.calls, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(resolver.calls, 2);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(pending.state.welcome, false);
    expect(pending.state.code, 'ABCD');
    expect(auth.state.invite, 'ABCD');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
