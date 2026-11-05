import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/auth/presentation/controller/session_controller.dart';
import 'package:phone_agent/features/settings/presentation/pages/account_route.dart';

class _Store implements SessionStore {
  AuthSession? saved = const AuthSession(
    accountId: 'synthetic-a',
    phone: '13800000000',
    accessToken: 'synthetic-not-a-credential',
  );
  int clears = 0;
  bool fail = false;
  Completer<void>? gate;
  @override
  Future<AuthSession?> read() async => saved;
  @override
  Future<void> write(AuthSession value) async => saved = value;
  @override
  Future<void> clear() async {
    clears++;
    await gate?.future;
    if (fail) throw StateError('synthetic storage failure');
    saved = null;
  }
}

Future<ProviderContainer> _host(WidgetTester tester, _Store store) async {
  final container = ProviderContainer(
    overrides: [sessionStoreProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  await container.read(sessionControllerProvider.notifier).restore();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => const AccountRoute()),
              ),
              child: const Text('root-account'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('root-account'));
  await tester.pumpAndSettle();
  return container;
}

Future<void> _dialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('account-delete')));
  await tester.pumpAndSettle();
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'account cancel, IME guard, exact input and single signout $platform',
      (tester) async {
        final store = _Store()..gate = Completer<void>();
        final container = await _host(tester, store);
        await _dialog(tester);
        expect(
          find.textContaining('138****0000', findRichText: true),
          findsOneWidget,
        );
        expect(
          find.textContaining('13800000000', findRichText: true),
          findsNothing,
        );
        final input = find.byKey(const Key('account-confirmation-input'));
        final submit = find.byKey(const Key('account-confirmation-submit'));
        expect(tester.widget<TextButton>(submit).onPressed, isNull);
        await tester.enterText(input, '确认');
        expect(tester.widget<TextButton>(submit).onPressed, isNull);
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: '确认注销',
            composing: TextRange(start: 0, end: 4),
          ),
        );
        await tester.pump();
        expect(tester.widget<TextButton>(submit).onPressed, isNull);
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(store.clears, 0);
        await _dialog(tester);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(store.clears, 0);
        await _dialog(tester);
        await tester.enterText(input, ' 确认注销\n');
        await tester.pump();
        final confirm = tester.widget<TextButton>(submit).onPressed!;
        confirm();
        confirm();
        await tester.pumpAndSettle();
        expect(store.clears, 1);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(AccountRoute), findsOneWidget);
        store.gate!.complete();
        await tester.pumpAndSettle();
        expect(
          container.read(sessionControllerProvider).phase,
          SessionPhase.signedOut,
        );
        expect(find.byType(AccountRoute), findsNothing);
        expect(find.text('root-account'), findsOneWidget);
      },
      variant: TargetPlatformVariant({platform}),
    );
  }

  testWidgets('failure remains on account and permits fresh confirmation', (
    tester,
  ) async {
    final store = _Store()..fail = true;
    await _host(tester, store);
    await _dialog(tester);
    await tester.enterText(find.byType(TextField), '确认注销');
    await tester.pump();
    await tester.tap(find.text('注销'));
    await tester.pumpAndSettle();
    expect(find.text('操作未完成，请重试'), findsOneWidget);
    expect(store.clears, 1);
    expect(find.byType(AccountRoute), findsOneWidget);
    store.fail = false;
    await _dialog(tester);
    await tester.enterText(find.byType(TextField), '确认注销');
    await tester.pump();
    await tester.tap(find.text('注销'));
    await tester.pumpAndSettle();
    expect(store.clears, 2);
    expect(find.byType(AccountRoute), findsNothing);
  });

  testWidgets('late confirmation cannot sign out replacement account', (
    tester,
  ) async {
    final store = _Store();
    final container = await _host(tester, store);
    await _dialog(tester);
    await container
        .read(sessionControllerProvider.notifier)
        .accept(
          const LoginOutcome(
            phone: '13900000000',
            inviteRequired: false,
            accountId: 'synthetic-b',
            accessToken: 'synthetic-new-credential',
          ),
        );
    await tester.enterText(find.byType(TextField), '确认注销');
    await tester.pump();
    await tester.tap(find.text('注销'));
    await tester.pumpAndSettle();
    expect(store.clears, 0);
    expect(
      container.read(sessionControllerProvider).session?.accountId,
      'synthetic-b',
    );
    expect(find.text('账号状态已变化，请重新进入账号页面'), findsOneWidget);
  });
}
