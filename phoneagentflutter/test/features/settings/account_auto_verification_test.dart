import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/native_notice.dart';
import 'package:phone_agent/features/account_cancellation/domain/account_cancellation.dart';
import 'package:phone_agent/features/account_cancellation/presentation/cancellation_controller.dart';
import 'package:phone_agent/features/account_cancellation/presentation/cancellation_coordinator.dart';
import 'package:phone_agent/features/account_cancellation/presentation/cancellation_providers.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import '../../support/cancellation_route_harness.dart';
import '../../support/cancellation_scenario.dart';
import '../../support/local_storage_channel_fake.dart';

final _input = find.byKey(const Key('verification-code-input'));
final _final = find.byKey(const Key('account-confirmation-submit'));
final _toast = find.byKey(const ValueKey('nativeNoticeSurface'));

Future<ProviderContainer> _start(
  WidgetTester tester,
  CancellationScenario gateway, {
  CancellationRouteStore? store,
  List<Override> overrides = const [],
}) async {
  final container = await hostCancellationRoute(
    tester,
    store ?? CancellationRouteStore(),
    gateway,
    overrides: overrides,
  );
  await openCancellationEntry(tester);
  await confirmCancellationEntry(tester);
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    installLocalStorageChannelFake();
  });
  tearDown(dismissNativeNotice);

  testWidgets('covering the page removes its toast without submitting', (
    tester,
  ) async {
    final gateway = CancellationScenario()..failVerification = true;
    await _start(tester, gateway);
    await tester.enterText(_input, '123456');
    await tester.pumpAndSettle();
    expect(_toast, findsOneWidget);
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('another-page')),
          ),
        );
    await tester.pumpAndSettle();
    expect(_toast, findsNothing);
    expect(gateway.submissions, 0);
  });

  testWidgets(
    'resend uses a new challenge, clears partial input and preserves cooldown',
    (tester) async {
      final gateway = _FreshDelivery();
      late _ClockCoordinator coordinator;
      await _start(
        tester,
        gateway,
        overrides: [
          cancellationCoordinatorProvider.overrideWith((ref) {
            coordinator = _ClockCoordinator(gateway);
            return coordinator;
          }),
        ],
      );
      await tester.enterText(_input, '12345');
      await tester.pump();
      expect(gateway.verifications, 0);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '60秒后重新发送'))
            .onPressed,
        isNull,
      );
      coordinator.now = coordinator.now.add(const Duration(seconds: 61));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('重新发送'));
      await tester.pumpAndSettle();
      expect(gateway.sends, 2);
      expect(tester.widget<TextField>(_input).controller!.text, isEmpty);
      expect(gateway.verifications, 0);
      await tester.enterText(_input, '123456');
      await tester.pumpAndSettle();
      expect(gateway.lastVerifiedChallenge, 'sms-2');
      expect(gateway.verifications, 1);
      expect(gateway.submissions, 0);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('six digits auto verify only after composition ends', (
    tester,
  ) async {
    final gateway = CancellationScenario();
    await _start(tester, gateway);
    await tester.enterText(_input, '12345');
    await tester.pump();
    expect(gateway.verifications, 0);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '123456',
        composing: TextRange(start: 0, end: 6),
        selection: TextSelection.collapsed(offset: 6),
      ),
    );
    await tester.pump();
    expect(gateway.verifications, 0);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '123456',
        selection: TextSelection.collapsed(offset: 6),
      ),
    );
    await tester.pumpAndSettle();
    expect(gateway.verifications, 1);
    expect(find.text('输入6位验证码'), findsOneWidget);
    expect(find.text('验证'), findsNothing);
    expect(find.text('继续注销'), findsNothing);
    expect(gateway.submissions, 0);
    expect(_final, findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'paste or autofill locks one request despite duplicate notifications',
    (tester) async {
      final gateway = _SlowVerification();
      await _start(tester, gateway);
      await tester.enterText(_input, '123456');
      await tester.pump();
      expect(gateway.verifications, 1);
      final field = tester.widget<TextField>(_input);
      expect(field.enabled, isFalse);
      field.controller!.selection = const TextSelection.collapsed(offset: 5);
      field.controller!.selection = const TextSelection.collapsed(offset: 6);
      await tester.pump(const Duration(seconds: 2));
      expect(gateway.verifications, 1);
      gateway.done.complete(
        CancellationVerification(
          'synthetic-proof',
          DateTime.utc(2099),
          gateway.confirmationData,
        ),
      );
      await tester.pumpAndSettle();
      expect(_final, findsOneWidget);
      expect(gateway.submissions, 0);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'identical failures each toast once, clear input and allow retry',
    (tester) async {
      final gateway = CancellationScenario()..failVerification = true;
      await _start(tester, gateway);
      for (var attempt = 1; attempt <= 2; attempt++) {
        await tester.enterText(_input, '123456');
        await tester.pumpAndSettle();
        expect(gateway.verifications, attempt);
        expect(tester.widget<TextField>(_input).controller!.text, isEmpty);
        expect(tester.widget<TextField>(_input).focusNode!.hasFocus, isTrue);
        expect(
          find.descendant(of: _toast, matching: find.textContaining('验证失败')),
          findsOneWidget,
        );
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(find.textContaining('验证失败'), findsNothing);
        expect(_toast, findsNothing);
        expect(gateway.verifications, attempt);
      }
      expect(gateway.submissions, 0);
    },
  );

  testWidgets(
    'sent toast expires without countdown replay and is removed on return',
    (tester) async {
      final gateway = CancellationScenario();
      await hostCancellationRoute(tester, CancellationRouteStore(), gateway);
      await openCancellationEntry(tester);
      await confirmCancellationEntry(tester);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: _toast, matching: find.text('验证码已发送')),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('验证码已发送'), findsNothing);
      expect(_toast, findsNothing);
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(_toast, findsNothing);
      expect(find.text('账号管理'), findsOneWidget);
    },
  );

  for (final leave in [false, true]) {
    testWidgets(
      'late verification cannot affect ${leave ? 'left route' : 'new account'}',
      (tester) async {
        final gateway = _SlowVerification();
        final store = CancellationRouteStore();
        final container = await _start(tester, gateway, store: store);
        await tester.enterText(_input, '123456');
        await tester.pump();
        expect(gateway.verifications, 1);
        if (leave) {
          tester.state<NavigatorState>(find.byType(Navigator).first).pop();
        } else {
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
        }
        gateway.done.complete(
          CancellationVerification(
            'synthetic-proof',
            DateTime.utc(2099),
            gateway.confirmationData,
          ),
        );
        await tester.pumpAndSettle();
        expect(_final, findsNothing);
        expect(_toast, findsNothing);
        expect(gateway.submissions, 0);
        expect(store.clears, 0);
      },
    );
  }

  testWidgets('account replacement dismisses an already visible toast', (
    tester,
  ) async {
    final gateway = CancellationScenario()..failVerification = true;
    final container = await _start(tester, gateway);
    await tester.enterText(_input, '123456');
    await tester.pumpAndSettle();
    expect(_toast, findsOneWidget);
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
    await tester.pumpAndSettle();
    expect(_toast, findsNothing);
  });

  testWidgets(
    'unknown application retains lookup action without another verification or submit',
    (tester) async {
      final gateway = CancellationScenario()
        ..loseResponse = true
        ..failQuery = true;
      final store = CancellationRouteStore();
      await _start(tester, gateway, store: store);
      await tester.enterText(_input, '123456');
      await tester.pumpAndSettle();
      await tester.tap(_final);
      await tester.pumpAndSettle();
      expect(gateway.verifications, 1);
      expect(gateway.submissions, 1);
      expect(gateway.queries, 1);
      expect(tester.widget<TextField>(_input).enabled, isFalse);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      await tester.tap(find.text('查询结果'));
      await tester.pumpAndSettle();
      expect(gateway.queries, 2);
      expect(gateway.submissions, 1);
      expect(gateway.verifications, 1);
      gateway.failQuery = false;
      await tester.tap(find.text('查询结果'));
      await tester.pumpAndSettle();
      expect(store.clears, 1);
    },
  );
}

class _SlowVerification extends CancellationScenario {
  final done = Completer<CancellationVerification>();
  @override
  Future<CancellationVerification> verify(
    CancellationDelivery delivery,
    String operationId,
    String code,
  ) {
    verifications++;
    return done.future;
  }
}

class _ClockCoordinator extends CancellationCoordinator {
  _ClockCoordinator(super.gateway);
  DateTime now = DateTime.utc(2026, 10, 27);
  @override
  CancellationController begin(
    CancellationConfirmation confirmation, {
    required bool Function() isCurrent,
  }) => CancellationController(
    gateway,
    confirmation,
    isCurrent: isCurrent,
    now: () => now,
  );
}

class _FreshDelivery extends CancellationScenario {
  String? lastVerifiedChallenge;
  @override
  Future<CancellationDelivery> send(
    CancellationConfirmation confirmation,
    String operationId,
  ) async {
    sends++;
    return CancellationDelivery(
      'sms-$sends',
      'synthetic-query-$sends',
      '138****0000',
      60,
    );
  }

  @override
  Future<CancellationVerification> verify(
    CancellationDelivery delivery,
    String operationId,
    String code,
  ) {
    lastVerifiedChallenge = delivery.challengeId;
    return super.verify(delivery, operationId, code);
  }
}
