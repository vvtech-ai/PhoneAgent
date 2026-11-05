import 'package:flutter/material.dart';
import '../../support/dial_permission_overrides.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/dialer_providers.dart';
import 'package:phone_agent/app/translation_providers.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_setup_controller.dart';
import 'package:phone_agent/app/dial_recent_providers.dart';
import 'package:phone_agent/features/dialer/data/dial_recent_sources.dart';
import 'package:phone_agent/features/dialer/domain/dial_recent_source.dart';
import 'package:phone_agent/features/dialer/data/system_dialer_channel.dart';
import 'package:phone_agent/features/dialer/presentation/controller/dialer_controller.dart';
import 'package:phone_agent/features/dialer/presentation/pages/dialer_route.dart';
import 'package:phone_agent/features/dialer/presentation/pages/dialer_page.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('large text dial keys scroll and retain actions on $platform', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var input = '', closes = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: DialerPage(
            state: const DialerState(),
            onCountry: () {},
            onDigit: (digit) => input += digit,
            onDelete: () {},
            onClear: () {},
            onDial: () => fail('must not dial'),
            onClose: () => closes++,
          ),
        ),
      );
      await tester.ensureVisible(find.byKey(const Key('dial-key-9')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dial-key-9')));
      expect(input, '9');
      await tester.ensureVisible(find.byKey(const Key('dial-close')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dial-close')));
      expect(closes, 1);
      expect(tester.takeException(), isNull);
    });
  }
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets('dial/country/search/delete/back at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => openDialer(
                    context,
                    preview: true,
                    number: '+12025550123',
                    name: '合成联系人',
                  ),
                  child: const Text('打开拨号盘'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开拨号盘'));
      await tester.pumpAndSettle();
      expect(find.text('MOCK · 拨号交互演练，不会拨出电话'), findsOneWidget);
      expect(find.text('202 555 0123'), findsOneWidget);
      expect(
        find.text('合成联系人'),
        findsNothing,
      ); // Native keeps target name in state, not an extra label.
      final setup = ProviderScope.containerOf(
        tester.element(find.byType(DialerPage)),
      ).read(translationSetupProvider.notifier);
      setup.enable(false);
      setup.prompt(false);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dial-country')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('dial-country-search')),
        'xjp',
      );
      await tester.pumpAndSettle();
      expect(find.text('新加坡'), findsOneWidget);
      expect(find.text('中国'), findsNothing);
      await tester.enterText(
        find.byKey(const Key('dial-country-search')),
        'zzzz',
      );
      await tester.pump();
      expect(find.text('暂无匹配的国家或地区'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('dial-country-search')),
        '86',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('dial-country-CN')));
      await tester.pumpAndSettle();
      await tester.longPress(find.byKey(const Key('dial-delete')));
      await tester.pumpAndSettle();
      expect(find.text('请输入号码'), findsOneWidget);
      expect(find.text('合成联系人'), findsNothing);
      for (final digit in '10086'.split('')) {
        await tester.ensureVisible(find.byKey(Key('dial-key-$digit')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key('dial-key-$digit')));
        await tester.pump();
      }
      await tester.ensureVisible(find.byKey(const Key('dial-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dial-delete')));
      await tester.pump();
      expect(find.text('100 8'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('dial-key-6')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dial-key-6')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('dial-call')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dial-call')));
      await tester.pumpAndSettle();
      expect(find.text('MOCK · 已模拟交给系统电话，没有拨出电话'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('dial-close')));
      await tester.tap(find.byKey(const Key('dial-close')));
      await tester.pumpAndSettle();
      expect(find.text('打开拨号盘'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'ordinary unsupported flow remains real, returns with state retained',
    (tester) async {
      final controller = DialerController(
        const SystemDialerChannel(supported: false),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            systemDialRecentSourceProvider.overrideWithValue(
              const UnavailableDialRecentSource(DialRecentAccess.unsupported),
            ),
            ...grantedDialPermissionOverrides(),
            dialerControllerProvider.overrideWith((ref) => controller),
            translationSetupProvider.overrideWith(
              (ref) => TranslationSetupController()
                ..enable(false)
                ..prompt(false),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => openDialer(context),
                  child: const Text('打开'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      for (final digit in '10086'.split('')) {
        await tester.ensureVisible(find.byKey(Key('dial-key-$digit')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key('dial-key-$digit')));
        await tester.pump();
      }
      await tester.tap(find.byKey(const Key('dial-call')));
      await tester.pumpAndSettle();
      expect(find.text('当前环境不能打开系统电话，没有发起通话'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      expect(find.text('100 86'), findsOneWidget);
      expect(find.text('MOCK · 拨号交互演练，不会拨出电话'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
