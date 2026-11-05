import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/online_entry_providers.dart';
import 'package:phone_agent/app/translation_providers.dart';
import 'package:phone_agent/core/design/native_notice.dart';
import 'package:phone_agent/features/dialer/presentation/pages/dialer_page.dart';
import 'package:phone_agent/features/settings/domain/network_availability.dart';
import 'package:phone_agent/features/translation/domain/translation_dial_preflight.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_lease.dart';
import 'package:phone_agent/features/translation/domain/sip/translation_call_plan.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_setup_controller.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_dial_session_binding.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_dialer_route.dart';

void main() {
  tearDown(dismissNativeNotice);
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final entry in <Object, String>{
      TranslationDialPreflightFailure.microphoneDenied: '请授予麦克风权限后再使用实时翻译通话',
      const SipLeaseFailure('INVITE_486'): '对方正在通话中',
      const TranslationPlanFailure(
        'POINTS_INSUFFICIENT_BALANCE',
        '积分不足，无法发起通话',
      ): '积分不足，无法发起通话',
      const TranslationPlanFailure('LOCATION_UNAVAILABLE', 'private'):
          '主叫所在国家尚未确认',
    }.entries) {
      testWidgets(
        'dial admission uses shared Toast for ${entry.value} $platform',
        (tester) async {
          final setup = TranslationSetupController()
            ..prompt(false)
            ..country('US');
          var attempts = 0;
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                translationSetupProvider.overrideWith((_) => setup),
                networkAvailabilitySourceProvider.overrideWithValue(
                  const UnknownNetworkAvailability(),
                ),
              ],
              child: MaterialApp(
                theme: ThemeData(platform: platform),
                home: TranslationDialerRoute(
                  preview: true,
                  number: '+12025550123',
                  sessionBinding: TranslationDialSessionBinding(
                    create: (_) async {
                      attempts++;
                      throw entry.key;
                    },
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          setup.language('en', caller: false);
          await tester.pumpAndSettle();
          for (var attempt = 1; attempt <= 2; attempt++) {
            tester.widget<DialerPage>(find.byType(DialerPage)).onDial();
            await tester.pumpAndSettle();
            expect(
              attempts,
              attempt,
              reason: tester
                  .widgetList<Text>(find.byType(Text))
                  .map((e) => e.data ?? e.textSpan?.toPlainText())
                  .join(' | '),
            );
            expect(find.text(entry.value), findsOneWidget);
            expect(
              find.byKey(const ValueKey('nativeNoticeSurface')),
              findsOneWidget,
            );
            expect(find.byKey(const Key('dial-message')), findsNothing);
            await tester.pump(const Duration(seconds: 3));
            await tester.pumpAndSettle();
            expect(find.text(entry.value), findsNothing);
          }
          final page = tester.widget<DialerPage>(find.byType(DialerPage));
          page.onClear();
          for (var digit = 0; digit < 15; digit++) {
            page.onDigit('1');
          }
          await tester.pumpAndSettle();
          expect(
            tester.widget<DialerPage>(find.byType(DialerPage)).state.input,
            '11111111111111',
          );
          expect(find.text('号码最多输入14位'), findsOneWidget);
          expect(find.byKey(const Key('dial-message')), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
