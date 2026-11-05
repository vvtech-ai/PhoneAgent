import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/invite/domain/invite.dart';
import 'package:phone_agent/features/invite/domain/invite_store.dart';
import 'package:phone_agent/features/invite/presentation/controller/invite_welcome_controller.dart';
import 'package:phone_agent/features/invite/presentation/controller/pending_invite_controller.dart';
import 'package:phone_agent/features/invite/presentation/widgets/invite_welcome_content.dart';

class Resolver implements InviteResolver {
  Resolver(this.code);
  final String code;
  @override
  Future<int> resolve(String _) async => throw InviteFailure(code);
}

void main() {
  for (final code in [
    'INVALID_CODE',
    'EXPIRED',
    'EXHAUSTED',
    'INVITE_ACTIVITY_CHANGED',
    'ACTIVITY_RETIRED',
    'NETWORK',
    'CONFIG_SYNC_PENDING',
    'UNKNOWN',
  ]) {
    test('welcome continuation policy $code', () async {
      final c = InviteWelcomeController(Resolver(code), 'ABCD');
      await c.load();
      expect(
        c.state.canContinue,
        !{'NETWORK', 'CONFIG_SYNC_PENDING', 'UNKNOWN'}.contains(code),
      );
      expect(c.state.points, isNull);
      expect(c.state.error, isNotEmpty);
      c.dispose();
    });
  }
  test(
    'Android errors retry while iOS business failures may continue',
    () async {
      for (final error in ['INVALID_CODE', 'EXPIRED', 'NETWORK']) {
        final controller = InviteWelcomeController(
          Resolver(error),
          'ABCD',
          allowBusinessFailure: false,
        );
        await controller.load();
        expect(controller.state.canContinue, false);
        expect(controller.state.error, isNotEmpty);
        controller.dispose();
      }
    },
  );
  test(
    'new external entries reopen welcome and submission protects attribution',
    () async {
      final pending = PendingInviteController(MemoryInviteStore());
      await pending.receive('ABCD');
      final first = pending.state.entryId;
      pending.continueLogin();
      await pending.receive('ABCD');
      expect(pending.state.welcome, true);
      expect(pending.state.entryId, greaterThan(first));
      final second = pending.state.entryId;
      final request = await pending.begin('13800000000', 'ABCD');
      await pending.receive('EFGH');
      expect(pending.state.code, 'ABCD');
      pending.finish();
      expect(await pending.begin('13800000000', 'ABCD'), request);
      pending.finish();
      await pending.receive('EFGH');
      expect(pending.state.code, 'EFGH');
      expect(pending.state.entryId, greaterThan(second));
      expect(await pending.begin('13800000000', 'EFGH'), isNot(request));
      pending.dispose();
    },
  );
  test(
    'consume welcome retains code and id; manual invalid draft survives restart',
    () async {
      final store = MemoryInviteStore();
      final p = PendingInviteController(store);
      await p.receive('ABCD');
      p.continueLogin();
      expect(p.state.welcome, false);
      expect(p.state.code, 'ABCD');
      final id = await p.begin('13800000000', 'ABCD');
      p.finish();
      final restored = PendingInviteController(store);
      await restored.initialize();
      expect(restored.state.welcome, false);
      expect(await restored.begin('13800000000', 'ABCD'), id);
      restored.finish();
      await restored.edit('未完成');
      final again = PendingInviteController(store);
      await again.initialize();
      expect(again.state.code, '未完成');
      expect((await store.read('pending'))['id'], isEmpty);
      p.dispose();
      restored.dispose();
      again.dispose();
    },
  );
  testWidgets('native welcome reward, retry and large type remain usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    var retries = 0;
    Widget page(InviteWelcomeState state) => MaterialApp(
      home: InviteWelcomeContent(
        code: 'ABCD',
        state: state,
        onBack: () {},
        onContinue: () {},
        onRetry: () => retries++,
      ),
    );
    await tester.pumpWidget(
      page(const InviteWelcomeState(points: 20, canContinue: true)),
    );
    expect(find.text('注册即得'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(find.text('注册时将自动填写'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('inviteWelcomeContinue')),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(page(const InviteWelcomeState(error: '网络失败')));
    await tester.ensureVisible(find.text('重新加载'));
    await tester.tap(find.text('重新加载'));
    expect(retries, 1);
  });
}
