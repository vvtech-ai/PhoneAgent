import 'support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/dialer_providers.dart';
import 'package:phone_agent/features/dialer/presentation/pages/dialer_page.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/app/translation_providers.dart';
import 'package:phone_agent/features/dialer/data/system_dialer_channel.dart';
import '../tool/previews/migration_workbench.dart';
import '../tool/previews/shell_contacts_preview.dart';
import '../tool/previews/workbench_catalog.dart';

void main() {
  test('production default still uses the actual platform adapter', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(systemDialerProvider), isA<SystemDialerChannel>());
  });

  for (final scale in [1.0, 2.0]) {
    for (final fromDialer in [false, true]) {
      testWidgets(
        'translation ordinary call stays scoped fromDialer=$fromDialer scale=$scale',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final nativeCalls = <MethodCall>[];
          const channel = MethodChannel('com.vvtech.phone_agent/system_dialer');
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          messenger.setMockMethodCallHandler(channel, (call) async {
            nativeCalls.add(call);
            return 'failed';
          });
          addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
          await tester.pumpWidget(
            MigrationWorkbench(
              scenes: [
                workbenchScenes.singleWhere((scene) => scene.id == 'app'),
              ],
            ),
          );
          Future<void> tap(Finder target) async {
            await tester.pumpUntilUiSettled();
            if (target.evaluate().isEmpty) {
              await tester.scrollUntilVisible(
                target,
                180,
                scrollable: find.byType(Scrollable).last,
              );
            }
            await Scrollable.ensureVisible(
              tester.element(target),
              alignment: .35,
            );
            await tester.pumpUntilUiSettled();
            await tester.tap(target);
            await tester.pumpUntilUiSettled();
            expect(tester.takeException(), isNull);
          }

          Future<void> key(String id) => tap(find.byKey(ValueKey(id)));
          await key('scene-app');
          final container = ProviderScope.containerOf(
            tester.element(find.byType(PhoneAgentApp)),
          );
          final setup = container.read(translationSetupProvider.notifier);
          if (fromDialer) {
            await tap(find.bySemanticsLabel('打开拨号盘'));
          } else {
            await key('skill-simultaneous_interpretation');
          }
          expect(
            find.descendant(
              of: find.byType(DialerPage),
              matching: find.textContaining('MOCK'),
            ),
            findsNothing,
            reason:
                'Normal dial UI must not expose migration rehearsal controls',
          );
          await key('translation-presets-open');
          await key('translation-enabled');
          await key('translation-prompt');
          await key('translation-presets-close');
          await key('dial-country');
          await key('dial-country-US');
          for (final digit in '2025550123'.split('')) {
            await key('dial-key-$digit');
          }
          expect(setup.snapshot.enabled, isFalse);
          expect(setup.snapshot.prompt, isFalse);
          expect(setup.snapshot.country, 'US');
          await key('dial-call');
          expect(find.text('请输入正确的电话号码'), findsNothing);
          expect(find.textContaining('本机记录保存失败'), findsNothing);
          expect(
            nativeCalls,
            isEmpty,
            reason: 'MOCK must never open the native dialer',
          );
          expect(container.read(shellContactsPortsProvider).openedNumbers, [
            '+12025550123',
          ]);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpUntilUiSettled();
        },
        variant: const TargetPlatformVariant({
          TargetPlatform.android,
          TargetPlatform.iOS,
        }),
      );
    }
  }
}
