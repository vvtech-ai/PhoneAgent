import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/invite_providers.dart';
import 'package:phone_agent/features/invite/presentation/pages/invite_activity_route.dart';
import 'package:phone_agent/features/invite/presentation/pages/invite_page.dart';
import 'invite_fakes.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'v67 activity rules poster copy records and source return at $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 680);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final repo = FakeInviteRepository();
        final device = FakeInviteDevice();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              inviteRepositoryProvider.overrideWithValue(repo),
              inviteDeviceProvider.overrideWithValue(device),
            ],
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const InviteActivityRoute(title: '福利'),
                      ),
                    ),
                    child: const Text('进入邀请'),
                  ),
                ),
              ),
            ),
          ),
        );
        Future<void> tap(String label) async {
          await tester.scrollUntilVisible(
            find.text(label),
            140,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.ensureVisible(find.text(label));
          await tester.pumpAndSettle();
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
        }

        await tester.tap(find.text('进入邀请'));
        await tester.pumpAndSettle();
        expect(find.text('福利'), findsOneWidget);
        expect(find.text('邀请记录'), findsOneWidget);
        expect(repo.recordCalls, 0);
        await tap('活动规则 ›');
        expect(find.text(sampleActivity.rules), findsOneWidget);
        await tester.tap(find.text('我知道了'));
        await tester.pumpAndSettle();
        await tap('邀请好友');
        expect(find.byType(InvitePage), findsOneWidget);
        expect(find.text('我的邀请码'), findsOneWidget);
        expect(find.text('复制邀请码'), findsNothing);
        await tap('复制链接');
        expect(device.copied, sampleCode.url);
        expect(repo.events, ['COPY_LINK']);
        await tester.pump(const Duration(milliseconds: 1800));
        await tester.pumpAndSettle();
        expect(find.text('已复制'), findsNothing);
        expect(find.byType(SnackBar), findsNothing);
        await tester.tap(find.byTooltip('返回').last);
        await tester.pumpAndSettle();
        expect(find.byType(InviteActivityRoute), findsOneWidget);
        await tap('邀请记录');
        expect(find.text('本期邀请记录'), findsOneWidget);
        expect(find.text('138****0000'), findsOneWidget);
        expect(repo.recordCalls, 1);
        await tester.tap(find.byTooltip('返回').last);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('返回'));
        await tester.pumpAndSettle();
        expect(find.text('进入邀请'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await device.received.close();
      },
    );
  }
}
