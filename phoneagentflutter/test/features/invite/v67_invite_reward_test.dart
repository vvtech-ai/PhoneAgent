import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/invite/presentation/widgets/invite_reward_card.dart';

void main() {
  for (final width in [320.0, 375.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('v67 credited reward artwork $width/$scale', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var confirmed = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 844),
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(
                body: Center(
                  child: InviteRewardCard(
                    amount: 300,
                    error: '',
                    onConfirm: () => confirmed++,
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text('好友邀请奖励已到账'), findsOneWidget);
        expect(find.text('+300'), findsOneWidget);
        expect(find.text('已存入你的积分账户'), findsOneWidget);
        Rect paintedTextRect(Finder finder) {
          final box = tester.renderObject<RenderBox>(finder);
          return MatrixUtils.transformRect(
            box.getTransformTo(null),
            Offset.zero & box.size,
          );
        }

        final title = paintedTextRect(find.text('好友邀请奖励已到账'));
        final amount = paintedTextRect(
          find.text('+300'),
        ).expandToInclude(paintedTextRect(find.text('积分')));
        final account = paintedTextRect(find.text('已存入你的积分账户'));
        final button = tester.getRect(find.byType(FilledButton));
        expect(title.bottom, lessThanOrEqualTo(amount.top));
        expect(
          amount.overlaps(account),
          isFalse,
          reason: '金额和账户说明必须可分别阅读，包含FittedBox实际绘制变换',
        );
        expect(amount.bottom, lessThanOrEqualTo(account.top));
        expect(account.bottom, lessThanOrEqualTo(button.top));
        expect(tester.widget<Text>(find.text('确定')).style?.color, Colors.white);
        await tester.tap(find.text('确定'));
        expect(confirmed, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('failed acknowledgement stays visible and busy cannot confirm', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InviteRewardCard(
            amount: 300,
            error: '无法保存已读状态，请重试',
            onConfirm: null,
          ),
        ),
      ),
    );
    expect(find.text('无法保存已读状态，请重试'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });
}
