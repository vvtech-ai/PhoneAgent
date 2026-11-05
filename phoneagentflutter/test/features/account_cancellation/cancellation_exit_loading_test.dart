import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/app/task_draft_cleanup.dart';
import 'package:phone_agent/features/account_cancellation/domain/account_cancellation.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/conversation/data/drafts/task_draft_account_store.dart';
import 'package:phone_agent/features/settings/presentation/pages/account_route.dart';
import '../../../tool/previews/shell_preview.dart';
import '../../support/cancellation_route_harness.dart';
import '../../support/cancellation_scenario.dart';
import '../../support/local_storage_channel_fake.dart';
import '../../support/pump_ui_transitions.dart';

class _Submission extends CancellationScenario {
  final done = Completer<void>();
  bool reject = false;
  @override
  Future<CancellationResult> submit(
    CancellationDelivery d,
    String op,
    String verification,
  ) async {
    submissions++;
    await done.future;
    if (reject) throw StateError('synthetic lost response');
    return result;
  }
}

class _Drafts extends TaskDraftAccountStore {
  _Drafts() : super(['synthetic-exit-loading']);
  final done = Completer<void>();
  bool entered = false;
  @override
  Future<void> clearAccount() {
    entered = true;
    return done.future;
  }
}

Future<ProviderContainer> _open(
  WidgetTester tester,
  CancellationRouteStore store,
  _Submission gateway, {
  _Drafts? drafts,
}) async {
  await tester.pumpWidget(
    ShellPreviewPage(
      sessionStore: store,
      cancellation: gateway,
      accountCleanup: drafts == null
          ? null
          : TaskDraftCleanup(drafts, onFailure: () {}),
    ),
  );
  await tester.pumpUntilUiSettled();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(PhoneAgentApp)),
  );
  unawaited(
    container
        .read(appRouterProvider)
        .routerDelegate
        .navigatorKey
        .currentState!
        .push<void>(MaterialPageRoute(builder: (_) => const AccountRoute())),
  );
  await tester.pumpUntilUiSettled();
  await openCancellationEntry(tester);
  await confirmCancellationEntry(tester);
  await tester.pumpUntilUiSettled();
  await tester.enterText(
    find.byKey(const Key('verification-code-input')),
    '123456',
  );
  await tester.pumpUntilUiSettled();
  expect(find.byKey(const Key('account-confirmation-submit')), findsOneWidget);
  await tester.tap(find.byKey(const Key('account-confirmation-submit')));
  await tester.pump(const Duration(milliseconds: 400));
  return container;
}

void _loading() {
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
  expect(find.text('输入6位验证码'), findsWidgets);
  expect(find.text('正在提交注销申请…'), findsNothing);
  expect(find.text('正在退出登录…'), findsNothing);
  expect(find.byKey(const ValueKey('loginPhone')), findsNothing);
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    installLocalStorageChannelFake();
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'one spinner preserves original surface through submission, storage and disposed-page cleanup $platform',
      (tester) async {
        final store = CancellationRouteStore()..gate = Completer<void>();
        final gateway = _Submission();
        final drafts = _Drafts();
        final container = await _open(tester, store, gateway, drafts: drafts);
        _loading();
        expect(gateway.submissions, 1);
        expect(store.clears, 0);
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(gateway.submissions, 1);
        _loading();
        gateway.done.complete();
        for (var frame = 0; frame < 4; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          _loading();
        }
        expect(store.clears, 1);
        expect(
          container.read(sessionControllerProvider.notifier).credentials,
          isNull,
        );
        store.gate!.complete();
        for (var frame = 0; frame < 4; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          _loading();
        }
        expect(drafts.entered, isTrue);
        expect(
          find.byType(AccountRoute),
          findsNothing,
        ); // Old providers really unmounted.
        drafts.done.complete();
        await tester.pumpUntilUiSettled();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byKey(const ValueKey('loginPhone')), findsOneWidget);
        expect(find.text('已提交注销申请'), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpUntilUiSettled();
        expect(find.text('已提交注销申请'), findsNothing);
        expect(gateway.submissions, 1);
        await tester.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant({platform}),
    );
  }
  for (final unknown in [false, true]) {
    testWidgets(
      'failed or unknown application stops loading without logging out: $unknown',
      (tester) async {
        final store = CancellationRouteStore();
        final gateway = _Submission()
          ..reject = true
          ..failQuery = unknown
          ..notSubmitted = !unknown;
        await _open(tester, store, gateway);
        _loading();
        gateway.done.complete();
        await tester.pumpUntilUiSettled();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(AccountRoute), findsOneWidget);
        expect(store.clears, 0);
        expect(gateway.submissions, 1);
        expect(gateway.queries, 1);
        expect(find.text('已提交注销申请'), findsNothing);
        if (unknown) expect(find.text('查询结果'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'failed accepted cleanup stops loading; retry only exits once without applying again',
    (tester) async {
      final store = CancellationRouteStore()..fail = true;
      final gateway = _Submission();
      final container = await _open(tester, store, gateway);
      gateway.done.complete();
      await tester.pumpUntilUiSettled();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(container.read(sessionControllerProvider).businessBlocked, isTrue);
      expect(
        container.read(sessionControllerProvider.notifier).credentials,
        isNull,
      );
      expect(find.text('重试退出'), findsOneWidget);
      expect(store.clears, 1);
      store.fail = false;
      store.gate = Completer<void>();
      await tester.tap(find.text('重试退出'));
      await tester.pump(const Duration(milliseconds: 16));
      _loading();
      expect(store.clears, 2);
      await tester.tapAt(
        tester.getCenter(find.byType(CircularProgressIndicator)),
      );
      await tester.pump();
      expect(store.clears, 2);
      expect(gateway.submissions, 1);
      store.gate!.complete();
      await tester.pumpUntilUiSettled();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byKey(const ValueKey('loginPhone')), findsOneWidget);
      expect(find.text('已提交注销申请'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'account replacement clears old cover and ignores late original submission',
    (tester) async {
      final store = CancellationRouteStore();
      final gateway = _Submission();
      final container = await _open(tester, store, gateway);
      _loading();
      final switching = container
          .read(sessionControllerProvider.notifier)
          .accept(
            const LoginOutcome(
              phone: '13900000000',
              inviteRequired: false,
              accountId: 'synthetic-b',
              accessToken: 'synthetic-next',
            ),
          );
      for (var frame = 0; frame < 4; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await switching;
      await tester.pumpUntilUiSettled();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      gateway.done.complete();
      await tester.pumpUntilUiSettled();
      expect(
        container.read(sessionControllerProvider).session?.accountId,
        'synthetic-b',
      );
      expect(store.clears, 0);
      expect(find.text('已提交注销申请'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
