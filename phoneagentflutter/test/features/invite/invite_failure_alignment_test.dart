import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/invite_providers.dart';
import 'package:phone_agent/features/invite/domain/invite.dart';
import 'package:phone_agent/features/invite/domain/invite_activity_failure.dart';
import 'package:phone_agent/features/invite/presentation/pages/invite_activity_route.dart';
import 'invite_fakes.dart';

class _Repository extends FakeInviteRepository {
  _Repository(this.failure);
  String? failure;
  @override
  Future<InviteOverview> activity() async {
    if (failure != null) throw InviteFailure(failure!);
    return super.activity();
  }
}

void main() {
  const activityCases = {
    'ACTIVITY_DISABLED': '活动暂未开放新邀请码',
    'ACTIVITY_UNAVAILABLE': '活动暂未开放新邀请码',
    'CONFIG_NOT_PUBLISHED': '活动暂未开放新邀请码',
    'CONFIG_SYNCING': '活动规则正在同步，请稍后重试',
    'CONFIG_SYNC_PENDING': '活动规则正在同步，请稍后重试',
    'INVITE_EXPIRED': '邀请码已过期，请刷新获取',
    'EXPIRED': '邀请码已过期，请刷新获取',
    'INVITE_ACTIVITY_CHANGED': '邀请活动已更新，请刷新获取新邀请码',
    'INVITE_REPLACED': '邀请活动已更新，请刷新获取新邀请码',
    'REPLACED': '邀请活动已更新，请刷新获取新邀请码',
    'QUOTA_EXHAUSTED': '邀请名额已用完',
    'EXHAUSTED': '邀请名额已用完',
    'INVITE_EXHAUSTED': '邀请名额已用完',
    'EXTERNAL_INVITE_UNAVAILABLE': '邀请服务暂不可用，请稍后重试',
    'INVALID_RESPONSE': '暂时无法加载邀请信息，请重试',
  };
  for (final entry in activityCases.entries) {
    test('AIAssistant1 activity message ${entry.key}', () {
      expect(
        inviteActivityFailureMessage(InviteFailure(entry.key)),
        entry.value,
      );
    });
  }
  const registrationCases = {
    'ACTIVITY_RETIRED': '本期邀请活动已结束，无法使用此邀请码完成注册。已有账号请返回登录。',
    'INVITE_ACTIVITY_RETIRED': '本期邀请活动已结束，无法使用此邀请码完成注册。已有账号请返回登录。',
    'EXPIRED': '邀请码已过期，请使用有效邀请码',
    'INVITE_EXPIRED': '邀请码已过期，请使用有效邀请码',
    'EXHAUSTED': '该邀请码名额已用完',
    'QUOTA_EXHAUSTED': '该邀请码名额已用完',
    'INVITE_EXHAUSTED': '该邀请码名额已用完',
    'INVITE_ACTIVITY_CHANGED': '邀请活动已更新，原邀请码已失效，请获取新邀请码',
    'REGISTRATION_RETRYABLE': '注册结果正在确认，请重试，勿更换邀请码',
  };
  for (final entry in registrationCases.entries) {
    test('AIAssistant1 registration message ${entry.key}', () {
      expect(InviteFailure(entry.key).message, entry.value);
    });
  }
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final failure in [
      'ACTIVITY_DISABLED',
      'INVITE_EXPIRED',
      'INVITE_ACTIVITY_CHANGED',
    ]) {
      testWidgets('$platform $failure shows aligned feedback and can retry', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 680);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final repo = _Repository(failure);
        final device = FakeInviteDevice();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              inviteRepositoryProvider.overrideWithValue(repo),
              inviteDeviceProvider.overrideWithValue(device),
            ],
            child: MaterialApp(
              theme: ThemeData(platform: platform),
              home: const InviteActivityRoute(title: '邀请好友'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(activityCases[failure]!), findsOneWidget);
        expect(find.text('活动规则 ›'), findsNothing);
        repo.failure = null;
        await tester.tap(find.text('刷新'));
        await tester.pumpAndSettle();
        expect(find.text(activityCases[failure]!), findsNothing);
        expect(find.text('活动规则 ›'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await device.received.close();
      });
    }
  }
}
