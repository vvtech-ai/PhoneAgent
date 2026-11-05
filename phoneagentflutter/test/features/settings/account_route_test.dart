import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import '../../support/cancellation_route_harness.dart';
import 'package:phone_agent/features/account_cancellation/domain/account_cancellation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../support/local_storage_channel_fake.dart';
import '../../support/cancellation_scenario.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phone_agent/core/storage/app_local_storage.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/auth/presentation/controller/session_controller.dart';
import 'package:phone_agent/features/settings/presentation/pages/account_route.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    installLocalStorageChannelFake();
  });
  for (final close in ['取消', '关闭', '返回']) {
    testWidgets(
      'entry $close performs zero storage and zero cancellation requests even if service fails',
      (tester) async {
        final gateway = _UnavailablePreparation();
        final store = CancellationRouteStore();
        await hostCancellationRoute(tester, store, gateway);
        var storageCalls = 0;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(AppLocalStorage.channel, (call) async {
              storageCalls++;
              return call.method == 'installed' ? true : null;
            });
        await openCancellationEntry(tester);
        expect(find.text('确认注销账号？'), findsOneWidget);
        if (close == '取消') {
          await tester.tap(find.text('取消'));
        } else if (close == '关闭') {
          await tester.tapAt(const Offset(5, 5));
        } else {
          await tester.binding.handlePopRoute();
        }
        await tester.pumpAndSettle();
        expect(storageCalls, 0);
        expect([
          gateway.confirmations,
          gateway.queries,
          gateway.sends,
          gateway.verifications,
          gateway.submissions,
        ], everyElement(0));
        expect(store.clears, 0);
        expect(find.textContaining('暂不可用'), findsNothing);
      },
    );
  }
  testWidgets(
    'unavailable service is requested only after entry confirmation',
    (tester) async {
      final gateway = _UnavailablePreparation();
      await hostCancellationRoute(tester, CancellationRouteStore(), gateway);
      await openCancellationEntry(tester);
      expect(gateway.confirmations, 0);
      await confirmCancellationEntry(tester);
      await tester.pumpAndSettle();
      expect(gateway.confirmations, 1);
      expect(gateway.sends, 0);
      expect(
        find.text(CancellationFailure.unavailable.message),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    },
  );
  for (final leave in [false, true]) {
    testWidgets(
      'slow preparation cannot send sms after ${leave ? 'leaving' : 'account change'}',
      (tester) async {
        final gateway = _SlowPreparation();
        final store = CancellationRouteStore();
        final container = await hostCancellationRoute(tester, store, gateway);
        await openCancellationEntry(tester);
        expect(gateway.confirmations, 0);
        await confirmCancellationEntry(tester);
        await tester.pump();
        expect(gateway.confirmations, 1);
        if (leave) {
          tester.state<NavigatorState>(find.byType(Navigator).first).pop();
          await tester.pumpAndSettle();
        } else {
          await container
              .read(sessionControllerProvider.notifier)
              .accept(
                const LoginOutcome(
                  phone: '13900000000',
                  inviteRequired: false,
                  accountId: 'synthetic-b',
                  accessToken: 'synthetic-b-token',
                ),
              );
        }
        gateway.done.complete(gateway.confirmationData);
        await tester.pumpAndSettle();
        expect(gateway.sends, 0);
        expect(gateway.submissions, 0);
        expect(store.clears, 0);
      },
    );
  }

  testWidgets('missing cancellation endpoint never sends sms or signs out', (
    tester,
  ) async {
    final gateway = _MissingPreparation();
    final store = CancellationRouteStore();
    final container = await hostCancellationRoute(tester, store, gateway);
    await openCancellationEntry(tester);
    expect(gateway.confirmations, 0);
    await confirmCancellationEntry(tester);
    await tester.pumpAndSettle();
    expect(gateway.confirmations, 1);
    expect([
      gateway.queries,
      gateway.sends,
      gateway.verifications,
      gateway.submissions,
    ], everyElement(0));
    expect(store.clears, 0);
    expect(
      container.read(sessionControllerProvider).phase,
      SessionPhase.signedIn,
    );
    expect(find.text('已提交注销申请'), findsNothing);
    expect(find.text('无法准备注销验证，请稍后重试'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'confirmation precedes sms; verification opens final confirmation before submitting and signs out once $platform',
      (tester) async {
        const legalChannel = MethodChannel('phone_agent/legal_documents');
        final opened = <MethodCall>[];
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(legalChannel, (call) async {
          opened.add(call);
          return null;
        });
        addTearDown(
          () => messenger.setMockMethodCallHandler(legalChannel, null),
        );
        final store = CancellationRouteStore();
        final gateway = CancellationScenario();
        final container = await hostCancellationRoute(tester, store, gateway);
        await openCancellationEntry(tester);
        expect(gateway.confirmations, 0);
        expect(gateway.queries, 0);
        expect(gateway.sends, 0);
        expect(store.clears, 0);
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(gateway.sends, 0);
        await openCancellationEntry(tester);
        await confirmCancellationEntry(tester);
        await tester.pumpAndSettle();
        expect(gateway.sends, 1);
        expect(store.clears, 0);
        expect(find.textContaining('138****0000'), findsOneWidget);
        expect(find.textContaining('13800000000'), findsNothing);
        await tester.enterText(
          find.byKey(const Key('verification-code-input')),
          '123456',
        );
        await tester.pump();
        await tester.pumpAndSettle();
        expect(gateway.verifications, 1);
        expect(gateway.submissions, 0);
        expect(store.clears, 0);
        expect(find.text('注销账号'), findsOneWidget);
        await tester.tap(
          find.byKey(const Key('account-cancellation-agreement')),
        );
        await tester.pumpAndSettle();
        expect(opened.single.method, 'openPublishedAgreement');
        expect(opened.single.arguments, accountCancellationAgreementUrl);
        expect(gateway.submissions, 0);
        expect(store.clears, 0);
        expect(
          find.byKey(const Key('account-confirmation-submit')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('account-confirmation-submit')));
        await tester.pumpAndSettle();
        expect(gateway.submissions, 1);
        expect(store.clears, 1);
        expect(
          container.read(sessionControllerProvider).phase,
          SessionPhase.signedOut,
        );
        expect(find.byType(AccountRoute), findsNothing);
      },
      variant: TargetPlatformVariant({platform}),
    );
  }
  for (final close in ['取消', '关闭']) {
    testWidgets(
      'final confirmation $close never applies; verification remains available',
      (tester) async {
        final store = CancellationRouteStore();
        final gateway = CancellationScenario();
        await hostCancellationRoute(tester, store, gateway);
        await openCancellationEntry(tester);
        expect(find.text('确认注销账号？'), findsOneWidget);
        await confirmCancellationEntry(tester);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('verification-code-input')),
          '123456',
        );
        await tester.pump();
        await tester.pumpAndSettle();
        expect(gateway.verifications, 1);
        expect(gateway.submissions, 0);
        if (close == '取消') {
          await tester.tap(find.text('取消'));
        } else {
          await tester.tapAt(const Offset(5, 5));
        }
        await tester.pumpAndSettle();
        expect(gateway.submissions, 0);
        expect(store.clears, 0);
        expect(find.text('继续注销'), findsNothing);
        expect(
          tester
              .widget<TextField>(
                find.byKey(const Key('verification-code-input')),
              )
              .controller!
              .text,
          isEmpty,
        );
        await tester.enterText(
          find.byKey(const Key('verification-code-input')),
          '123456',
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('account-confirmation-submit')),
          findsOneWidget,
        );
        expect(gateway.verifications, 2);
        expect(gateway.submissions, 0);
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('返回'));
        await tester.pumpAndSettle();
        expect(find.text('账号管理'), findsOneWidget);
      },
    );
  }
  testWidgets(
    'invalid verification never opens final confirmation or signs out',
    (tester) async {
      final store = CancellationRouteStore();
      final gateway = CancellationScenario()..failVerification = true;
      await hostCancellationRoute(tester, store, gateway);
      await openCancellationEntry(tester);
      await confirmCancellationEntry(tester);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('verification-code-input')),
        '123456',
      );
      await tester.pump();
      await tester.pumpAndSettle();
      expect(gateway.verifications, 1);
      expect(gateway.submissions, 0);
      expect(store.clears, 0);
      expect(
        find.byKey(const Key('account-confirmation-submit')),
        findsNothing,
      );
      expect(find.textContaining('验证失败'), findsOneWidget);
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
    },
  );
  testWidgets('late final confirmation cannot submit for replacement account', (
    tester,
  ) async {
    final store = CancellationRouteStore();
    final gateway = CancellationScenario();
    final container = await hostCancellationRoute(tester, store, gateway);
    await openCancellationEntry(tester);
    await confirmCancellationEntry(tester);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('verification-code-input')),
      '123456',
    );
    await tester.pump();
    await tester.pumpAndSettle();
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
    await tester.tap(find.byKey(const Key('account-confirmation-submit')));
    await tester.pumpAndSettle();
    expect(gateway.submissions, 0);
    expect(store.clears, 0);
  });

  testWidgets('late confirmation cannot request sms for replacement account', (
    tester,
  ) async {
    final store = CancellationRouteStore();
    final gateway = CancellationScenario();
    final container = await hostCancellationRoute(tester, store, gateway);
    await openCancellationEntry(tester);
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
    await confirmCancellationEntry(tester);
    await tester.pumpAndSettle();
    expect(gateway.sends, 0);
    expect(store.clears, 0);
    expect(
      container.read(sessionControllerProvider).session?.accountId,
      'synthetic-b',
    );
  });
  testWidgets(
    'accepted application with failed cleanup blocks account requests',
    (tester) async {
      final store = CancellationRouteStore()..fail = true;
      final gateway = CancellationScenario();
      final container = await hostCancellationRoute(tester, store, gateway);
      await openCancellationEntry(tester);
      await confirmCancellationEntry(tester);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('verification-code-input')),
        '123456',
      );
      await tester.pump();
      await tester.pumpAndSettle();
      expect(gateway.submissions, 0);
      await tester.tap(find.byKey(const Key('account-confirmation-submit')));
      await tester.pumpAndSettle();
      expect(gateway.submissions, 1);
      expect(container.read(sessionControllerProvider).businessBlocked, isTrue);
      expect(
        container.read(sessionControllerProvider.notifier).credentials,
        isNull,
      );
    },
  );
}

class _UnavailablePreparation extends CancellationScenario {
  @override
  Future<CancellationConfirmation> confirmation() async {
    confirmations++;
    throw CancellationFailure.unavailable;
  }
}

class _SlowPreparation extends CancellationScenario {
  final done = Completer<CancellationConfirmation>();
  @override
  Future<CancellationConfirmation> confirmation() {
    confirmations++;
    return done.future;
  }
}

class _MissingPreparation extends CancellationScenario {
  @override
  Future<CancellationConfirmation> confirmation() async {
    confirmations++;
    throw ApiFailure.rejected; // AccountApi's existing 404 failure projection.
  }
}
