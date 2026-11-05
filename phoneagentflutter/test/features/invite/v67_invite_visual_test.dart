import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/invite_providers.dart';
import 'package:phone_agent/features/invite/domain/invite.dart';
import 'package:phone_agent/features/invite/presentation/pages/invite_activity_route.dart';
import 'package:phone_agent/features/invite/presentation/pages/invite_page.dart';
import 'package:phone_agent/features/invite/presentation/pages/invite_records_page.dart';
import 'package:phone_agent/features/invite/presentation/widgets/invite_reward_card.dart';
import 'package:phone_agent/features/invite/presentation/widgets/invite_welcome_content.dart';
import 'package:phone_agent/features/invite/presentation/controller/invite_welcome_controller.dart';
import 'package:phone_agent/features/invite/presentation/controller/invite_records_controller.dart';
import 'package:phone_agent/features/invite/presentation/controller/invite_controller.dart';
import 'package:phone_agent/features/invite/presentation/widgets/invite_activity_card.dart';
import 'package:phone_agent/features/points/domain/points_wallet.dart'
    as points;
import 'package:phone_agent/features/points/presentation/controller/points_wallet_controller.dart';
import 'package:phone_agent/features/points/presentation/pages/points_wallet_page.dart';
import 'invite_fakes.dart';

const snapshotActivity = InviteActivity(
  id: 'synthetic-v67',
  name: '邀请好友，一起体验 AI 通话',
  rules: '仅限新用户，积分以到账为准。',
  inviterPoints: 300,
  inviteePoints: 300,
  quota: 12,
  bonusEnabled: true,
  bonusThreshold: 10,
  bonusPoints: 500,
  longTerm: true,
);
const snapshotOverview = InviteOverview(
  snapshotActivity,
  InvitePersonal(true, 2, 300, 500, false),
);

Widget recordsSnapshot(InviteRecordsState state) => Scaffold(
  backgroundColor: const Color(0xFFF5F7FA),
  body: SafeArea(
    child: InviteRecordsPage(
      state: state,
      quota: 12,
      onBack: () {},
      onRefresh: () async {},
      onLoadNext: () {},
    ),
  ),
);

Widget activitySnapshot(InviteState state) => Scaffold(
  backgroundColor: const Color(0xFFF5F7FA),
  body: SafeArea(
    child: ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        InviteActivityCard(
          state: state,
          onRefresh: () {},
          onRules: () {},
          onRecords: () {},
        ),
      ],
    ),
  ),
);

class SnapshotInviteRepository extends FakeInviteRepository {
  @override
  Future<InviteOverview> activity() async => snapshotOverview;
  @override
  Future<InviteCode> code() async => const InviteCode(
    'ABCD',
    'https://example.test/invite/?code=ABCD',
    '2099-01-01T00:00:00Z',
    2,
    0,
    10,
    snapshotOverview,
  );
}

void main() {
  const capture = String.fromEnvironment('COMMERCE_CAPTURE_DIR');
  setUpAll(() async {
    if (capture.isEmpty) return;
    for (final font in const {
      'ReferenceText': String.fromEnvironment('UI_PREFLIGHT_FONT'),
      'Roboto': String.fromEnvironment('UI_PREFLIGHT_FONT'),
      'Ahem': String.fromEnvironment('UI_PREFLIGHT_FONT'),
      'MaterialIcons': String.fromEnvironment('UI_PREFLIGHT_ICON_FONT'),
    }.entries) {
      final loader = FontLoader(font.key)
        ..addFont(File(font.value).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
    await Directory(capture).create(recursive: true);
  });
  final pages = <String, Widget>{
    'v67-welfare': const InviteActivityRoute(title: '福利'),
    'v67-activity-loading': activitySnapshot(
      const InviteState(overview: snapshotOverview, loading: true),
    ),
    'v67-activity-error': activitySnapshot(
      const InviteState(overview: snapshotOverview, error: '邀请信息加载失败，请重试'),
    ),
    'v67-records-loading': recordsSnapshot(
      const InviteRecordsState(loading: true),
    ),
    'v67-records-empty': recordsSnapshot(const InviteRecordsState()),
    'v67-records-error': recordsSnapshot(
      const InviteRecordsState(error: '邀请记录加载失败，请重试'),
    ),
    'v67-records-more-error': recordsSnapshot(
      const InviteRecordsState(
        items: [
          InviteRecord('one', '138****3508', '2026-08-29T02:18:00Z', 300),
        ],
        total: 3,
        cursor: 'next-synthetic-page',
        error: '邀请记录加载失败，请重试',
      ),
    ),
    'v67-poster': const InvitePage(),
    'v67-reward': Scaffold(
      backgroundColor: Colors.black38,
      body: Center(
        child: InviteRewardCard(amount: 300, error: '', onConfirm: () {}),
      ),
    ),
    'v67-welcome': InviteWelcomeContent(
      code: 'ABCD',
      state: const InviteWelcomeState(points: 300, canContinue: true),
      onBack: () {},
      onContinue: () {},
      onRetry: () {},
    ),
    'v67-invite-records': Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: InviteRecordsPage(
          state: const InviteRecordsState(
            items: [
              InviteRecord(
                'one',
                '138****3508',
                '2026-08-29T02:18:00Z',
                300,
                credited: true,
              ),
              InviteRecord('two', '139****8821', '2026-08-28T06:20:00Z', 800),
            ],
            total: 2,
          ),
          quota: 12,
          onBack: () {},
          onRefresh: () async {},
          onLoadNext: () {},
        ),
      ),
    ),
    'v67-points-ledger': Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      body: SafeArea(
        child: PointsLedgerPage(
          state: const PointsWalletState(
            ledgerAvailable: true,
            items: [
              points.PointsLedgerItem(
                id: 1,
                type: 'MEMBERSHIP_GRANT',
                title: '会员积分赠送',
                delta: 1500,
                balanceAfter: 2100,
                description: '会员每月赠送积分',
                occurredAt: '2026-10-12T10:00:00',
              ),
              points.PointsLedgerItem(
                id: 2,
                type: 'POINTS_PACK',
                title: '购买积分',
                delta: 1000,
                balanceAfter: 3100,
                description: '积分包购买',
                occurredAt: '2026-10-12T10:05:00',
              ),
              points.PointsLedgerItem(
                id: 3,
                type: 'USAGE',
                title: '通话消耗',
                delta: -100,
                balanceAfter: 3000,
                description: '积分消耗',
                occurredAt: '2026-10-12T10:10:00',
              ),
            ],
          ),
          onBack: () {},
          onRefresh: () async {},
          onLoadNext: () {},
        ),
      ),
    ),
  };
  for (final width in [375.0, 390.0, 430.0]) {
    for (final entry in pages.entries) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('${entry.key} source widths $width scale $scale', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          const key = Key('v67-ui-capture');
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                inviteRepositoryProvider.overrideWithValue(
                  SnapshotInviteRepository(),
                ),
                inviteDeviceProvider.overrideWithValue(FakeInviteDevice()),
              ],
              child: MaterialApp(
                theme: ThemeData(
                  fontFamily: capture.isEmpty ? null : 'ReferenceText',
                ),
                home: RepaintBoundary(
                  key: key,
                  child: MediaQuery(
                    data: MediaQueryData(
                      size: Size(width, 844),
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: entry.value,
                  ),
                ),
              ),
            ),
          );
          if (entry.key.endsWith('-loading')) {
            await tester.pump(const Duration(milliseconds: 300));
          } else {
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull);
          if (capture.isNotEmpty) {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(key),
            );
            await tester.runAsync(() async {
              final image = await boundary.toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                '$capture/${entry.key}-${width.toInt()}${scale == 1 ? '' : '-2x'}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        });
      }
    }
  }
}
