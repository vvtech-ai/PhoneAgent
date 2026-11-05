import '../test/support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/app_call_record_providers.dart';
import 'package:phone_agent/app/contact_providers.dart';
import 'package:phone_agent/app/developer_list_providers.dart';
import 'package:phone_agent/app/outbound_number_providers.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/app/settings_providers.dart';
import 'package:phone_agent/features/settings/data/preview_outbound_number_repository.dart';
import 'package:phone_agent/features/settings/presentation/pages/developer_tools_route.dart';

/// Starts anywhere in the shared MOCK shell, ends at home without logging out.
Future<void> verifyDeveloperStage(
  WidgetTester tester, {
  required Future<void> Function(String) capture,
}) async {
  Future<void> tap(Finder target) async {
    await tester.pumpUntilUiSettled();
    if (find.byType(SnackBar).evaluate().isNotEmpty) {
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpUntilUiSettled();
    }
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        target,
        160,
        scrollable: find.byType(Scrollable).last,
      );
    }
    await Scrollable.ensureVisible(tester.element(target), alignment: 0.35);
    await tester.pumpUntilUiSettled();
    await tester.tap(target);
    await tester.pumpUntilUiSettled();
    expect(tester.takeException(), isNull);
  }

  Future<void> key(String id) => tap(find.byKey(ValueKey(id)));
  Future<void> back() async {
    if (find.byTooltip('返回').evaluate().isNotEmpty) {
      await tester.tap(find.byTooltip('返回'));
    } else {
      await tester.pageBack();
    }
    await tester.pumpUntilUiSettled();
    expect(tester.takeException(), isNull);
  }

  Future<void> input(String text) async {
    await tester.enterText(
      find.byKey(const Key('outbound-number-input')),
      text,
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    await tester.pumpUntilUiSettled();
  }

  final container = ProviderScope.containerOf(
    tester.element(find.byType(PhoneAgentApp)),
  );
  await key('tab-0');
  await tap(find.bySemanticsLabel('打开拨号盘'));
  // A preceding scenario may retain a dial draft: clear by the actual control.
  final delete = find.byKey(const Key('dial-delete'));
  await tester.ensureVisible(delete);
  await tester.longPress(delete);
  await tester.pumpUntilUiSettled();
  for (final digit in '20142014*#'.split('')) {
    await key('dial-key-$digit');
  }
  await key('dial-call');
  expect(container.read(developerModeProvider), isTrue);
  expect(find.text('已进入开发者模式'), findsOneWidget);
  await key('dial-close');
  await key('tab-3');
  await key('settings-developer');
  expect(find.byType(DeveloperToolsRoute), findsOneWidget);
  expect(find.text('尚未配置固定外呼号码'), findsOneWidget);
  await capture('33-developer-home');

  final repository =
      container.read(outboundNumberRepositoryProvider)
          as PreviewOutboundNumberRepository;
  await tap(find.text('固定外呼号码'));
  await input('+12025550101');
  repository.failWrite = true;
  await tap(find.text('保存'));
  expect(find.text('保存结果未确认，可重新读取核对或再次保存'), findsOneWidget);
  await capture('34-outbound-save-failure');
  repository.failWrite = false;
  await tap(find.text('保存'));
  expect(repository.value.number, '+12025550101');
  await tap(find.text('固定外呼号码'));
  await input('+12025550102');
  await back();
  await tap(find.text('固定外呼号码'));
  expect(
    tester
        .widget<TextField>(find.byKey(const Key('outbound-number-input')))
        .controller!
        .text,
    '+12025550101',
  );
  await capture('35-outbound-reopened');
  await tap(find.text('删除固定外呼号码'));
  expect(repository.value.number, isEmpty);
  expect(repository.deletes, 1);

  final records = container.read(appCallRecordRepositoryProvider)!;
  await key('developer-list-filled');
  expect(await records.load(), isEmpty);
  expect(container.read(developerListControllerProvider).failed, false);
  expect(container.read(contactsControllerProvider).contacts, isNotEmpty);
  await key('developer-list-empty');
  expect(container.read(contactsControllerProvider).contacts, isEmpty);
  await capture('36-developer-lists');
  await tap(find.text('重置'));
  expect(find.byKey(const Key('translation-model-open')), findsOneWidget);
  await key('dial-close');
  expect(find.byType(DeveloperToolsRoute), findsOneWidget);
  await key('developer-network-offline');
  await back();
  await key('tab-0');
  await key('skill-restaurant_booking');
  expect(find.text('无网络连接'), findsOneWidget);
  await capture('37-developer-network-block');
  await tap(find.text('关闭'));
  await key('tab-3');
  await key('settings-developer');
  await key('developer-network-normal');
  await back();
  await key('settings-logout');
  expect(find.byKey(const ValueKey('logout-confirm')), findsOneWidget);
  await capture('38-logout-cancel');
  await tap(find.text('取消'));
  await key('tab-0');
  expect(find.byKey(const Key('skill-restaurant_booking')), findsOneWidget);
}
