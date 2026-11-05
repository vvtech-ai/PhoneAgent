import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/invite_providers.dart';
import 'package:phone_agent/features/invite/presentation/pages/invite_activity_route.dart';
import 'package:phone_agent/features/invite/presentation/pages/invite_records_page.dart';
import 'package:phone_agent/features/invite/presentation/controller/invite_records_controller.dart';
import 'package:phone_agent/features/invite/domain/invite.dart';
import 'invite_fakes.dart';

void main() {
  testWidgets('first records failure stays below header with usable retry', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InviteRecordsPage(
            state: const InviteRecordsState(error: '邀请记录加载失败，请重试'),
            quota: 12,
            onBack: () {},
            onRefresh: () async {
              retries++;
            },
            onLoadNext: () {},
          ),
        ),
      ),
    );
    final headerBottom = tester.getBottomLeft(find.byType(Divider)).dy;
    final errorTop = tester.getTopLeft(find.text('邀请记录加载失败，请重试')).dy;
    expect(errorTop - headerBottom, inInclusiveRange(18, 40));
    await tester.tap(find.text('重试'));
    expect(retries, 1);
  });
  testWidgets('v67 welfare records and poster return to original activity', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inviteRepositoryProvider.overrideWithValue(FakeInviteRepository()),
          inviteDeviceProvider.overrideWithValue(FakeInviteDevice()),
        ],
        child: const MaterialApp(home: InviteActivityRoute(title: '福利')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('福利'), findsOneWidget);
    await tester.tap(find.text('邀请记录'));
    await tester.pumpAndSettle();
    expect(find.text('本期邀请记录'), findsOneWidget);
    expect(find.text('138****0000'), findsOneWidget);
    expect(find.text('到账中'), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('福利'), findsOneWidget);
  });
  for (final width in [375.0, 390.0, 430.0]) {
    testWidgets('record original columns and empty state width $width 2x', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 844),
              textScaler: const TextScaler.linear(2),
            ),
            child: Scaffold(
              body: InviteRecordsPage(
                state: const InviteRecordsState(
                  items: [
                    InviteRecord(
                      'r',
                      '138****3508',
                      '2026-08-29T02:18:00Z',
                      300,
                      credited: true,
                    ),
                  ],
                  total: 1,
                ),
                quota: 12,
                onBack: () {},
                onRefresh: () async {},
                onLoadNext: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('8/29 10:18'), findsOneWidget);
      expect(find.text('已到账'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
