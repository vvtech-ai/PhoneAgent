import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/invite/domain/invite.dart';
import 'package:phone_agent/features/invite/presentation/controller/invite_welcome_controller.dart';
import 'package:phone_agent/features/invite/presentation/widgets/invite_welcome_content.dart';

class _Resolver implements InviteResolver {
  _Resolver(this.failure);
  String? failure;
  @override
  Future<int> resolve(String code) async {
    if (failure != null) throw InviteFailure(failure!);
    return 20;
  }
}

void main() {
  for (final ios in [false, true]) {
    final cases = <(String, String, bool)>[
      ('INVITE_ACTIVITY_RETIRED', '本期邀请活动已结束，无法使用此邀请码完成注册。已有账号请返回登录。', true),
      ('INVITE_EXPIRED', '邀请码已过期，请使用有效邀请码', true),
      ('INVITE_EXHAUSTED', '该邀请码名额已用完', true),
      ('INVITE_ACTIVITY_CHANGED', '邀请活动已更新，原邀请码已失效，请获取新邀请码', true),
      ('CONFIG_NOT_PUBLISHED', '邀请活动尚未发布', false),
      ('CONFIG_SYNC_PENDING', '活动规则正在同步，请稍后重试', false),
      ('EXTERNAL_INVITE_UNAVAILABLE', '邀请服务暂不可用，请稍后重试', false),
      ('NETWORK', ios ? '暂时无法加载邀请信息，请重试' : '邀请信息加载失败，请重试', false),
      ('INVALID_RESPONSE', ios ? '暂时无法加载邀请信息，请重试' : '邀请信息加载失败，请重试', false),
    ];
    for (final value in cases) {
      testWidgets('native welcome ios=$ios error=${value.$1}', (tester) async {
        tester.view.physicalSize = const Size(320, 680);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final controller = InviteWelcomeController(
          _Resolver(value.$1),
          'ABCD',
          allowBusinessFailure: ios,
        );
        addTearDown(controller.dispose);
        await controller.load();
        expect(controller.state.error, value.$2);
        expect(controller.state.canContinue, ios && value.$3);
        expect(controller.state.points, isNull);
        var continued = 0, retries = 0, back = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: InviteWelcomeContent(
              code: 'ABCD',
              state: controller.state,
              onContinue: () => continued++,
              onRetry: () => retries++,
              onBack: () => back++,
            ),
          ),
        );
        expect(find.text(value.$2), findsOneWidget);
        expect(find.text('注册即得'), findsNothing);
        final action = ios && value.$3 ? '立即体验 Phone Agent' : '重新加载';
        await tester.ensureVisible(find.text(action));
        await tester.tap(find.text(action));
        expect(continued, ios && value.$3 ? 1 : 0);
        expect(retries, ios && value.$3 ? 0 : 1);
        await tester.ensureVisible(find.text('‹ 返回'));
        await tester.tap(find.text('‹ 返回'));
        expect(back, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
    test('network retry restores real reward ios=$ios', () async {
      final resolver = _Resolver('NETWORK');
      final controller = InviteWelcomeController(
        resolver,
        'ABCD',
        allowBusinessFailure: ios,
      );
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.state.canContinue, false);
      resolver.failure = null;
      await controller.load();
      expect(controller.state.error, isEmpty);
      expect(controller.state.points, 20);
      expect(controller.state.canContinue, true);
    });
  }
}
