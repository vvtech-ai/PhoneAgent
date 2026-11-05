import 'dart:ui' as ui;
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/app/task_draft_cleanup.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/conversation/data/drafts/task_draft_account_store.dart';
import '../tool/previews/shell_preview.dart';
import 'support/cancellation_route_harness.dart';
import 'support/local_storage_channel_fake.dart';
import 'support/pump_ui_transitions.dart';

class _Drafts extends TaskDraftAccountStore {
  _Drafts() : super(['synthetic-forced-exit']);
  final gate = Completer<void>();
  bool entered = false;
  @override
  Future<void> clearAccount() {
    entered = true;
    return gate.future;
  }
}

void loading() {
  expect(find.byKey(const Key('forced-session-exit-surface')), findsOneWidget);
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
  expect(find.text('输入6位验证码'), findsNothing);
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    installLocalStorageChannelFake();
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'ordinary logout does not acquire forced overlay $platform',
      (tester) async {
        final store = CancellationRouteStore()..gate = Completer<void>();
        await tester.pumpWidget(ShellPreviewPage(sessionStore: store));
        await tester.pumpUntilUiSettled();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(PhoneAgentApp)),
        );
        final session = container.read(sessionControllerProvider.notifier);
        final exit = session.signOut();
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          find.byKey(const Key('forced-session-exit-surface')),
          findsNothing,
        );
        store.gate!.complete();
        await tester.pumpUntilUiSettled();
        await exit;
        await tester.pumpUntilUiSettled();
        expect(find.byKey(const ValueKey('loginPhone')), findsOneWidget);
        expect(
          find.byKey(const Key('forced-session-exit-surface')),
          findsNothing,
        );
        await tester.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant({platform}),
    );
    testWidgets(
      'failed forced cleanup stops loading and retry is isolated $platform',
      (tester) async {
        final store = CancellationRouteStore()
          ..fail = true
          ..gate = Completer<void>();
        await tester.pumpWidget(ShellPreviewPage(sessionStore: store));
        await tester.pumpUntilUiSettled();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(PhoneAgentApp)),
        );
        final session = container.read(sessionControllerProvider.notifier);
        final owner = session.credentials!;
        final exit = session.invalidateSession(
          owner,
          SessionInvalidationReason.cancellationPending,
        );
        await tester.pump(const Duration(milliseconds: 16));
        loading();
        final duplicate = session.invalidateSession(
          owner,
          SessionInvalidationReason.cancellationPending,
        );
        expect(store.clears, 1);
        store.gate!.complete();
        await tester.pumpUntilUiSettled();
        await exit;
        await duplicate;
        expect(
          find.byKey(const Key('forced-session-exit-surface')),
          findsNothing,
        );
        expect(find.text('重试退出'), findsOneWidget);
        expect(session.credentials, isNull);
        store.fail = false;
        store.gate = Completer<void>();
        await tester.tap(find.text('重试退出'));
        await tester.pump(const Duration(milliseconds: 16));
        loading();
        store.gate!.complete();
        await tester.pumpUntilUiSettled();
        expect(store.clears, 2);
        expect(find.byKey(const ValueKey('loginPhone')), findsOneWidget);
        expect(
          find.byKey(const Key('forced-session-exit-surface')),
          findsNothing,
        );
        await tester.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant({platform}),
    );
    testWidgets(
      'replacement account clears old forced transition $platform',
      (tester) async {
        final store = CancellationRouteStore()
          ..fail = true
          ..gate = Completer<void>();
        await tester.pumpWidget(ShellPreviewPage(sessionStore: store));
        await tester.pumpUntilUiSettled();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(PhoneAgentApp)),
        );
        final session = container.read(sessionControllerProvider.notifier);
        final owner = session.credentials!;
        final exit = session.invalidateSession(
          owner,
          SessionInvalidationReason.cancelled,
        );
        await tester.pump(const Duration(milliseconds: 16));
        loading();
        store.gate!.complete();
        await tester.pumpUntilUiSettled();
        await exit;
        store.fail = false;
        final accepted = session.accept(
          const LoginOutcome(
            phone: '13900000000',
            inviteRequired: false,
            accountId: 'synthetic-b',
            accessToken: 'synthetic-b-token',
          ),
        );
        await tester.pumpUntilUiSettled();
        await accepted;
        await session.invalidateSession(
          owner,
          SessionInvalidationReason.cancelled,
        );
        await tester.pumpUntilUiSettled();
        expect(session.credentials?.accountId, 'synthetic-b');
        expect(store.clears, 1);
        expect(
          find.byKey(const Key('forced-session-exit-surface')),
          findsNothing,
        );
        await tester.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant({platform}),
    );
    testWidgets(
      'forced cancellation covers storage and released-page cleanup $platform',
      (tester) async {
        final store = CancellationRouteStore()..gate = Completer<void>();
        final drafts = _Drafts();
        await tester.pumpWidget(
          ShellPreviewPage(
            sessionStore: store,
            accountCleanup: TaskDraftCleanup(drafts, onFailure: () {}),
          ),
        );
        await tester.pumpUntilUiSettled();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(PhoneAgentApp)),
        );
        final session = container.read(sessionControllerProvider.notifier);
        final owner = session.credentials!;
        final navigator = container
            .read(appRouterProvider)
            .routerDelegate
            .navigatorKey
            .currentState!;
        unawaited(
          navigator.push<void>(
            MaterialPageRoute(
              builder: (_) => const Scaffold(
                backgroundColor: Color(0xFF00A050),
                body: Text('旧业务页'),
              ),
            ),
          ),
        );
        await tester.pumpUntilUiSettled();
        final exit = session.invalidateSession(
          owner,
          SessionInvalidationReason.cancelled,
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          loading();
        }
        expect(session.credentials, isNull);
        expect(find.text('旧业务页'), findsNothing);
        store.gate!.complete();
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          loading();
        }
        expect(
          find.byKey(const Key('forced-session-exit-image')),
          findsOneWidget,
        );
        final image = tester
            .widget<RawImage>(
              find.byKey(const Key('forced-session-exit-image')),
            )
            .image!;
        expect(image.width * image.height, lessThanOrEqualTo(2000000));
        final pixels = await tester.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
        );
        final offset =
            ((image.height ~/ 2) * image.width + image.width ~/ 2) * 4;
        expect(List.generate(4, (i) => pixels!.getUint8(offset + i)), [
          0,
          160,
          80,
          255,
        ]);
        expect(drafts.entered, isTrue);
        expect(store.clears, 1);
        drafts.gate.complete();
        for (var frame = 0; frame < 6; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          if (find
              .byKey(const Key('forced-session-exit-surface'))
              .evaluate()
              .isEmpty) {
            expect(find.byKey(const ValueKey('loginPhone')), findsOneWidget);
          } else {
            loading();
          }
        }
        await tester.pumpUntilUiSettled();
        await exit;
        await tester.pumpUntilUiSettled();
        expect(find.byKey(const ValueKey('loginPhone')), findsOneWidget);
        expect(
          find.byKey(const Key('forced-session-exit-surface')),
          findsNothing,
        );
        expect(image.debugDisposed, isTrue);
        expect(find.text('已提交注销申请'), findsNothing);
        await tester.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant({platform}),
    );
  }
}
