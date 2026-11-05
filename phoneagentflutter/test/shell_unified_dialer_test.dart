import 'support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/app/translation_providers.dart';
import 'package:phone_agent/app/settings_providers.dart';
import 'package:phone_agent/features/dialer/presentation/pages/dialer_page.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_dialer_route.dart';
import '../tool/previews/migration_workbench.dart';
import '../tool/previews/workbench_catalog.dart';
import '../tool/previews/shell_contacts_preview.dart';

void main() {
  testWidgets(
    'formal entries use one dialer and preserve draft and unlock',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MigrationWorkbench(
          scenes: [workbenchScenes.singleWhere((s) => s.id == 'app')],
        ),
      );
      Future<void> tap(Finder finder) async {
        if (finder.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            finder,
            180,
            scrollable: find.byType(Scrollable).last,
          );
        }
        await tester.ensureVisible(finder);
        await tester.pumpUntilUiSettled();
        await tester.tap(finder);
        await tester.pumpUntilUiSettled();
      }

      Future<void> key(String id) => tap(find.byKey(ValueKey(id)));
      await key('scene-app');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PhoneAgentApp)),
      );
      final setup = container.read(translationSetupProvider.notifier);
      await tester.pumpUntilUiSettled();
      setup.enable(false);
      setup.prompt(false);
      await tester.pumpUntilUiSettled();
      await tap(find.bySemanticsLabel('打开拨号盘'));
      expect(find.byType(TranslationDialerRoute), findsOneWidget);
      expect(find.text('实时翻译配置'), findsNothing);
      expect(find.byKey(const Key('translation-presets-open')), findsOneWidget);
      expect(setup.snapshot.enabled, isFalse);
      for (final digit in '2025550101'.split('')) {
        await key('dial-key-$digit');
      }
      await key('dial-country');
      await key('dial-country-US');
      await key('dial-close');
      expect(find.byType(TranslationDialerRoute), findsNothing);
      await tap(find.bySemanticsLabel('打开拨号盘'));
      var page = tester.widget<DialerPage>(find.byType(DialerPage));
      expect(page.state.input, '2025550101');
      expect(page.state.countryIso, 'US');
      await key('dial-close');
      await key('skill-simultaneous_interpretation');
      expect(find.byType(TranslationDialerRoute), findsOneWidget);
      expect(find.byType(DialerPage, skipOffstage: false), findsOneWidget);
      expect(setup.snapshot.enabled, isTrue);
      page = tester.widget<DialerPage>(find.byType(DialerPage));
      expect(page.state.input, '2025550101');
      page.onClear();
      await tester.pumpUntilUiSettled();
      for (final digit in '20142014*#'.split('')) {
        await key('dial-key-$digit');
      }
      await key('dial-call');
      expect(find.text('开发者功能已开启，请返回设置查看'), findsOneWidget);
      expect(container.read(developerModeProvider), isTrue);
      expect(container.read(shellContactsPortsProvider).openedNumbers, isEmpty);
      expect(
        tester.widget<DialerPage>(find.byType(DialerPage)).state.input,
        isEmpty,
      );
      await key('dial-close');
      expect(find.bySemanticsLabel('打开拨号盘'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );
}
