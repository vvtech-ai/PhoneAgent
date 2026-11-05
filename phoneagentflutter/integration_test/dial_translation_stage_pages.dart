import '../test/support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/app/dial_recent_providers.dart';
import 'package:phone_agent/app/translation_providers.dart';
import 'package:phone_agent/features/translation/presentation/widgets/translation_presets.dart';
import '../tool/previews/shell_contacts_preview.dart';
import '../tool/previews/shell_translation_preview.dart';

/// Shared device/VM journey. The channel guard prevents an override regression
/// from opening a real phone app; a nonzero count still fails the stage.
Future<void> verifyDialTranslationStage(
  WidgetTester tester, {
  required Future<void> Function(String) capture,
}) async {
  const channel = MethodChannel('com.vvtech.phone_agent/system_dialer');
  final nativeCalls = <MethodCall>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(channel, (call) async {
    nativeCalls.add(call);
    return 'failed';
  });
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  final container = ProviderScope.containerOf(
    tester.element(find.byType(PhoneAgentApp)),
  );
  Future<void> frame() async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  Future<void> tap(Finder target, {bool settle = true}) async {
    await frame();
    await Scrollable.ensureVisible(tester.element(target), alignment: .35);
    await frame();
    await tester.tap(target);
    await frame();
    // Cupertino transitions on a device can outlive one fixed frame delay.
    // Only the explicit media-ready wait has an intentional active spinner.
    if (settle) await tester.pumpUntilUiSettled();
    expect(tester.takeException(), isNull);
  }

  Future<void> key(String id) => tap(find.byKey(ValueKey(id)));
  Future<void> clearNumber() async {
    final target = find.byKey(const ValueKey('dial-delete'));
    await Scrollable.ensureVisible(tester.element(target), alignment: .35);
    await frame();
    await tester.longPress(target);
    await frame();
  }

  await tap(find.bySemanticsLabel('打开拨号盘'));
  // The merged dialer renders translation configuration in the same route.
  // The prior contact stage deliberately leaves its number in the shared dialer.
  await clearNumber();
  await key('translation-presets-open');
  await tap(find.widgetWithText(NativeTranslationPresetSwitchRow, '实时翻译'));
  await tap(find.widgetWithText(NativeTranslationPresetSwitchRow, '拨号前打开本提示'));
  await key('translation-presets-close');
  await key('dial-country');
  await tester.enterText(find.byType(TextField), '不存在国家');
  await frame();
  expect(find.text('暂无匹配的国家或地区'), findsOneWidget);
  await tester.enterText(find.byType(TextField), '美国');
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await frame();
  await capture('22-country-search');
  await key('dial-country-US');
  for (final digit in '2025550123'.split('')) {
    await key('dial-key-$digit');
  }
  final contacts = container.read(shellContactsPortsProvider);
  final callsBefore = contacts.openedNumbers.length;
  await key('dial-call');
  expect(nativeCalls, isEmpty);
  expect(contacts.openedNumbers.length, callsBefore + 1);
  expect(contacts.openedNumbers.last, '+12025550123');
  expect(find.textContaining('本机记录保存失败'), findsNothing);
  await key('translation-presets-open');
  await tap(find.widgetWithText(NativeTranslationPresetSwitchRow, '实时翻译'));
  await key('translation-caller');
  await key('language-ja');
  expect(find.text('日语'), findsOneWidget);
  expect(container.read(translationSetupProvider).value.caller, 'ja');
  await key('translation-caller');
  await key('language-zh');
  await key('translation-presets-close');
  await key('translation-model-open');
  await tap(find.text('GPT Live Translate'));
  expect(container.read(translationSetupProvider).value.provider, 'OPENAI');
  await capture('23-translation-options');
  await key('translation-presets-open');
  await tap(find.widgetWithText(NativeTranslationPresetSwitchRow, '拨号前打开本提示'));
  await key('translation-presets-close');
  final preview = container.read(shellTranslationCompletionProvider);
  await key('dial-call');
  await key('translation-presets-close');
  expect(preview.activeFixture, isNull);
  await key('dial-call');
  await tap(find.widgetWithText(FilledButton, '实时翻译呼叫'), settle: false);
  final fixture = preview.activeFixture!;
  expect(fixture.creates, 1);
  expect(fixture.merchants, 0);
  await tap(find.text('注入媒体就绪'));
  expect(fixture.merchants, 1);
  await tap(find.text('注入对方接通'));
  await tap(find.text('注入双语字幕'));
  expect(find.text('这是一条合成对话。'), findsOneWidget);
  await key('translation-control-静音');
  await key('translation-control-扬声器');
  await key('translation-control-拨号盘');
  await key('translation-dtmf-5');
  expect(fixture.trace, containsAll(['mute:true', 'speaker:true', 'dtmf:5']));
  await capture('24-translation-controls');
  await key('translation-control-挂断');
  await tester.pump(const Duration(milliseconds: 600));
  await frame();
  expect(fixture.hangups, 1);
  expect(fixture.live.closed, isTrue);
  expect(preview.archivePorts.archived, hasLength(1));
  expect(container.read(dialRecentProvider).records, hasLength(1));
  await clearNumber();
  expect(find.text('+12025550123'), findsOneWidget);
  await capture('25-translation-recent');
  await key('dial-close');
  expect(nativeCalls, isEmpty);
}
