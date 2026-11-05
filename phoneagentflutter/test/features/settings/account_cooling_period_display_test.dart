import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/account_cancellation/domain/account_cancellation.dart';
import 'package:phone_agent/core/design/native_business_dialog.dart';
import 'package:phone_agent/core/design/auth_tokens.dart';
import 'package:phone_agent/features/settings/presentation/widgets/account_confirmation_dialog.dart';

void main() {
  for (final seconds in <int?>[null, 30, 60, 300, 3600, 7200, 86400, 1296000]) {
    testWidgets(
      'final confirmation matches approved copy and dynamic server time for period $seconds',
      (tester) async {
        bool? result;
        var opened = 0;
        final effectiveAt = seconds == null
            ? DateTime.utc(2026, 10, 28, 9, 5)
            : DateTime.utc(2027, 1, 1, 17, 37);
        final expectedTime = seconds == null
            ? '2026年10月28日 17:05（北京时间）'
            : '2027年01月02日 01:37（北京时间）';
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showAccountConfirmation(
                      context,
                      '',
                      confirmation: CancellationConfirmation(
                        'confirmation',
                        '1.0',
                        accountCancellationAgreementUrl,
                        effectiveAt,
                        coolingPeriodSeconds: seconds,
                      ),
                      openAgreement: () async {
                        opened++;
                      },
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        final content = tester
            .widget<NativeBusinessDialog>(find.byType(NativeBusinessDialog))
            .content!;
        final body = tester
            .widgetList<Text>(
              find.descendant(
                of: find.byWidget(content),
                matching: find.byType(Text),
              ),
            )
            .map((text) => text.data ?? text.textSpan!.toPlainText())
            .join();
        expect(
          body,
          '点击注销后，账号将在 $expectedTime 完成注销。'
          '期间若再次登录，注销流程将自动终止。'
          '继续注销，即视为你已阅读并同意《PhoneAgent 账号注销协议》。',
        );
        expect(find.textContaining(expectedTime), findsOneWidget);
        expect(find.textContaining('{完成时间}'), findsNothing);
        expect(find.byType(Checkbox), findsNothing);
        expect(find.byType(TextField), findsNothing);
        expect(
          find.byKey(const Key('account-cancellation-agreement')),
          findsOneWidget,
        );
        final link = find.byKey(const Key('account-cancellation-agreement'));
        final button = tester.widget<TextButton>(link);
        expect(button.style!.foregroundColor!.resolve({}), AuthTokens.accent);
        await tester.tap(link);
        await tester.pumpAndSettle();
        expect(opened, 1);
        expect(result, isNull);
        final cancel = seconds == null || seconds == 300 || seconds == 7200;
        await tester.tap(
          cancel
              ? find.text('取消')
              : find.byKey(const Key('account-confirmation-submit')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('account-confirmation-submit')),
          findsNothing,
        );
        expect(result, cancel ? isFalse : isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
