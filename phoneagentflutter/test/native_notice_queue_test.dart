import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/session_navigation_host.dart';
import 'package:phone_agent/core/design/native_notice.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/auth/presentation/controller/session_controller.dart';
import '../tool/previews/auth_scenario.dart';

Future<BuildContext> mountNotices(
  WidgetTester tester, {
  TargetPlatform platform = TargetPlatform.android,
}) async {
  late BuildContext context;
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      home: Builder(
        builder: (value) {
          context = value;
          return const Scaffold(body: Text('页面'));
        },
      ),
    ),
  );
  return context;
}

Future<void> expireNotice(WidgetTester tester, Duration hold) async {
  await tester.pump(const Duration(milliseconds: 181));
  await tester.pump(hold);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 181));
  await tester.pump();
  await tester.pump();
}

void main() {
  tearDown(dismissNativeNotice);
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform queues notices with independent full durations', (
      tester,
    ) async {
      final context = await mountNotices(tester, platform: platform);
      showNativeNotice(context, '登录成功');
      showNativeNotice(
        context,
        '初始赠送 ✦800 积分已到账',
        duration: const Duration(seconds: 4),
      );
      showNativeNotice(
        context,
        '今日登录赠送 ✦100 积分已到账',
        duration: const Duration(seconds: 4),
      );
      await tester.pump();
      expect(find.text('登录成功'), findsOneWidget);
      expect(find.text('初始赠送 ✦800 积分已到账'), findsNothing);
      await expireNotice(tester, const Duration(milliseconds: 1800));
      expect(find.text('登录成功'), findsNothing);
      expect(find.text('初始赠送 ✦800 积分已到账'), findsOneWidget);
      expect(find.text('今日登录赠送 ✦100 积分已到账'), findsNothing);
      await tester.pump(const Duration(milliseconds: 181));
      await tester.pump(const Duration(milliseconds: 3999));
      expect(find.text('初始赠送 ✦800 积分已到账'), findsOneWidget);
      expect(find.text('今日登录赠送 ✦100 积分已到账'), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 181));
      await tester.pump();
      await tester.pump();
      expect(find.text('今日登录赠送 ✦100 积分已到账'), findsOneWidget);
      expect(find.byKey(const ValueKey('nativeNoticeSurface')), findsOneWidget);
      await expireNotice(tester, const Duration(seconds: 4));
      expect(find.byKey(const ValueKey('nativeNoticeSurface')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('append during fade-out waits; empty notice does not interrupt', (
    tester,
  ) async {
    final context = await mountNotices(tester);
    showNativeNotice(context, '第一条', duration: const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 181));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    showNativeNotice(context, '');
    showNativeNotice(context, '第二条');
    await tester.pump();
    expect(find.text('第一条'), findsOneWidget);
    expect(find.text('第二条'), findsNothing);
    await tester.pump(const Duration(milliseconds: 91));
    await tester.pump();
    await tester.pump();
    expect(find.text('第二条'), findsOneWidget);
    await expireNotice(tester, const Duration(milliseconds: 1800));
  });

  testWidgets('clear removes backlog and old disposal cannot clear new queue', (
    tester,
  ) async {
    final context = await mountNotices(tester);
    showNativeNotice(context, '旧当前');
    showNativeNotice(context, '旧等待');
    await tester.pump();
    dismissNativeNotice();
    dismissNativeNotice();
    showNativeNotice(context, '新提示');
    await tester.pump();
    await tester.pump();
    expect(find.text('新提示'), findsOneWidget);
    expect(find.text('旧当前'), findsNothing);
    expect(find.text('旧等待'), findsNothing);
    await expireNotice(tester, const Duration(milliseconds: 1800));
    expect(find.text('旧等待'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('destroyed overlay drops backlog and next overlay works', (
    tester,
  ) async {
    final oldContext = await mountNotices(tester);
    showNativeNotice(oldContext, '旧当前');
    showNativeNotice(oldContext, '旧等待');
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    final context = await mountNotices(tester);
    showNativeNotice(oldContext, '已失效页面');
    showNativeNotice(context, '新Overlay');
    await tester.pump();
    expect(find.text('新Overlay'), findsOneWidget);
    expect(find.text('旧等待'), findsNothing);
    await expireNotice(tester, const Duration(milliseconds: 1800));
    expect(tester.takeException(), isNull);
  });

  testWidgets('same account navigation preserves queued notices', (
    tester,
  ) async {
    final context = await mountNotices(tester);
    showNativeNotice(context, '第一条');
    showNativeNotice(context, '第二条');
    await tester.pump();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('新页面')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('新页面'), findsOneWidget);
    expect(find.text('第一条'), findsOneWidget);
    await expireNotice(tester, const Duration(milliseconds: 1800));
    expect(find.text('第二条'), findsOneWidget);
    await expireNotice(tester, const Duration(milliseconds: 1800));
  });

  testWidgets('changing overlay clears old queue before new entry builds', (
    tester,
  ) async {
    late BuildContext rootContext, nestedContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            rootContext = context;
            return Scaffold(
              body: Overlay(
                initialEntries: [
                  OverlayEntry(
                    builder: (context) {
                      nestedContext = context;
                      return const Text('嵌套页面');
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    showNativeNotice(rootContext, '根当前');
    showNativeNotice(rootContext, '根等待');
    showNativeNotice(nestedContext, '嵌套当前');
    await tester.pump();
    await tester.pump();
    expect(find.text('根当前'), findsNothing);
    expect(find.text('根等待'), findsNothing);
    expect(find.text('嵌套当前'), findsOneWidget);
    await expireNotice(tester, const Duration(milliseconds: 1800));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'disposing session host clears queue while root overlay survives',
    (tester) async {
      final session = SessionController(AuthScenario(AuthScenarioKind.direct));
      final visible = ValueNotifier(true);
      addTearDown(session.dispose);
      addTearDown(visible.dispose);
      late BuildContext oldContext, nextContext;
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: visible,
            builder: (_, shown, _) => shown
                ? SessionNavigationHost(
                    session: session,
                    epoch: null,
                    child: Builder(
                      builder: (context) {
                        oldContext = context;
                        return const Scaffold(body: Text('旧宿主'));
                      },
                    ),
                  )
                : Builder(
                    builder: (context) {
                      nextContext = context;
                      return const Scaffold(body: Text('新宿主'));
                    },
                  ),
          ),
        ),
      );
      showNativeNotice(oldContext, '旧当前');
      showNativeNotice(oldContext, '旧等待');
      await tester.pump();
      visible.value = false;
      await tester.pump();
      await tester.pump();
      showNativeNotice(nextContext, '新提示');
      await tester.pump();
      expect(find.text('旧当前'), findsNothing);
      expect(find.text('旧等待'), findsNothing);
      expect(find.text('新提示'), findsOneWidget);
      await expireNotice(tester, const Duration(milliseconds: 1800));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'session release clears current and backlog before next account',
    (tester) async {
      final session = SessionController(AuthScenario(AuthScenarioKind.direct));
      addTearDown(session.dispose);
      const account = LoginOutcome(
        phone: '13800000000',
        accountId: 'synthetic',
        accessToken: 'synthetic-token',
        inviteRequired: false,
      );
      await session.accept(account);
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: SessionNavigationHost(
            session: session,
            epoch: session.credentials!.epoch,
            child: Builder(
              builder: (value) {
                context = value;
                return const Scaffold(body: Text('当前账号'));
              },
            ),
          ),
        ),
      );
      showNativeNotice(context, '旧账号当前');
      showNativeNotice(context, '旧账号等待');
      await tester.pump();
      final owner = session.credentials!;
      expect(await session.replaceToken(owner, 'synthetic-refreshed'), isTrue);
      await tester.pump();
      expect(find.text('旧账号当前'), findsOneWidget);
      final signOut = session.signOut();
      await tester.pump();
      await signOut;
      await tester.pump();
      expect(find.text('旧账号当前'), findsNothing);
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('旧账号等待'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
