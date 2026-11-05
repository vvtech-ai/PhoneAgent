import 'support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/dial_recent_providers.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/app/translation_dial_binding_provider.dart';
import 'package:phone_agent/app/translation_providers.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import '../tool/previews/auth_scenario.dart';
import '../tool/previews/migration_workbench.dart';
import '../tool/previews/shell_translation_preview.dart';
import '../tool/previews/workbench_catalog.dart';

void main() {
  test('unconfigured production never supplies an implicit call binding', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(translationDialSessionBindingProvider), isNull);
  });

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets(
      'shell translation confirmation call records and reset $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final scene = workbenchScenes.singleWhere((s) => s.id == 'app');
        await tester.pumpWidget(MigrationWorkbench(scenes: [scene]));
        Future<void> frame() async {
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
          await tester.pump();
        }

        Future<void> tap(Finder target) async {
          // Preflight deliberately waits for user-injected readiness; do not
          // advance its spinner until the real ten-second timeout in tests.
          await frame();
          if (target.evaluate().isEmpty) {
            await tester.scrollUntilVisible(
              target,
              220,
              scrollable: find.byType(Scrollable).last,
            );
          }
          await Scrollable.ensureVisible(
            tester.element(target),
            alignment: .35,
          );
          await frame();
          await tester.tap(target);
          await frame();
          expect(tester.takeException(), isNull);
        }

        Future<void> key(String id) => tap(find.byKey(ValueKey(id)));
        await key('scene-app');
        final container = ProviderScope.containerOf(
          tester.element(find.byType(PhoneAgentApp)),
        );
        final auth = container.read(sessionStoreProvider) as AuthScenario;
        expect(container.read(appConfigProvider).apiBaseUri, isNull);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('skill-simultaneous_interpretation')),
          250,
        );
        await key('skill-simultaneous_interpretation');
        await key('translation-model-open');
        await tap(find.text('GPT Live Translate'));
        expect(
          container.read(translationSetupProvider).value.provider,
          'OPENAI',
        );
        for (final digit in '2025550123'.split('')) {
          await key('dial-key-$digit');
        }
        final preview = container.read(shellTranslationCompletionProvider);
        await key('dial-call');
        await key('translation-presets-close');
        expect(preview.activeFixture, isNull);
        await key('dial-call');
        await tap(find.widgetWithText(FilledButton, '实时翻译呼叫'));
        final fixture = preview.activeFixture!;
        expect(fixture.creates, 1);
        expect(fixture.merchants, 0);
        expect(fixture.lastCreate!.phone, '+12025550123');
        expect(fixture.lastCreate!.provider, 'OPENAI');
        expect(
          find.text('注入媒体就绪'),
          findsOneWidget,
          reason: 'Media must await readiness: ${fixture.trace}',
        );
        await tap(find.text('注入媒体就绪'));
        expect(fixture.merchants, 1);
        await tap(find.text('注入对方接通'));
        await tap(find.text('注入双语字幕'));
        expect(find.text('这是一条合成对话。'), findsOneWidget);
        expect(find.text('我明白了。'), findsOneWidget);
        await key('translation-control-静音');
        await key('translation-control-扬声器');
        await key('translation-control-拨号盘');
        await key('translation-dtmf-5');
        expect(
          fixture.trace,
          containsAll(['mute:true', 'speaker:true', 'dtmf:5']),
        );
        await key('translation-control-挂断');
        await tester.pump(const Duration(milliseconds: 600));
        await frame();
        expect(fixture.hangups, 1);
        expect(fixture.live.closed, isTrue);
        expect(find.byKey(const Key('dial-call')), findsOneWidget);
        expect(container.read(dialRecentProvider).records.length, 1);
        expect(preview.archivePorts.archived.length, 1);
        expect(preview.lastDial!.phone, '+12025550123');
        expect(
          container.read(translationSetupProvider).value.provider,
          'OPENAI',
        );
        expect(auth.sends, 0);

        await tester.ensureVisible(find.byKey(const Key('dial-delete')));
        await tester.longPress(find.byKey(const Key('dial-delete')));
        await frame();
        expect(find.text('+12025550123'), findsOneWidget);
        await key('dial-close');
        await key('tab-3');
        await key('settings-logout');
        await tap(find.byKey(const ValueKey('logout-confirm')));
        await tester.enterText(
          find.byKey(const ValueKey('loginPhone')),
          '13800000000',
        );
        await tester.enterText(find.byKey(const ValueKey('loginCode')), '123456');
        await key('loginAgreement');
        await key('loginBtn');
        final newLogin = container.read(shellTranslationCompletionProvider);
        expect(identical(newLogin, preview), isFalse);
        expect(await newLogin.store.repository.load(), isEmpty);
        expect(newLogin.activeFixture, isNull);
        expect(auth.sends, 0);

        await key('workbench-home');
        await key('scene-app');
        final fresh = ProviderScope.containerOf(
          tester.element(find.byType(PhoneAgentApp)),
        );
        expect(identical(fresh, container), isFalse);
        final reset = fresh.read(shellTranslationCompletionProvider);
        expect(reset.activeFixture, isNull);
        expect(await reset.store.repository.load(), isEmpty);
        await key('workbench-home');
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpUntilUiSettled();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
