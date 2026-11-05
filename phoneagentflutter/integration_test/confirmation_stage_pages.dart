import '../test/support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/calls/presentation/pages/call_session_page.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/batch_confirmation_card.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/call_confirmation_card.dart';
import '../tool/previews/auth_scenario.dart';
import '../tool/previews/migration_workbench.dart';
import '../tool/previews/shell_call_preview.dart';
import '../tool/previews/shell_conversation_ports.dart';
import '../tool/previews/workbench_catalog.dart';

/// Full shared App; only IO is synthetic. No device/account data is read.
Future<void> verifyConfirmationStage(
  WidgetTester tester, {
  required Future<void> Function(String) capture,
}) async {
  final forbidden = <String>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final name in [
    'plugins.it_nomads.com/flutter_secure_storage',
    'phone_agent/legacy_confirmation_billing',
    'com.vvtech.phone_agent/system_dialer',
    'phone_agent/pcm_output',
  ]) {
    final channel = MethodChannel(name);
    messenger.setMockMethodCallHandler(channel, (call) async {
      forbidden.add('$name:${call.method}');
      throw PlatformException(code: 'forbidden_in_stage');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  }
  final oldFatal = WidgetController.hitTestWarningShouldBeFatal;
  WidgetController.hitTestWarningShouldBeFatal = true;
  addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = oldFatal);

  Future<void> visible(Finder target) async {
    await tester.pumpUntilUiSettled();
    for (var attempt = 0; attempt < 3; attempt++) {
      if (target.evaluate().isEmpty) {
        final timeline = find.descendant(
          of:
              find
                  .byKey(const ValueKey('conversation-timeline'))
                  .evaluate()
                  .isNotEmpty
              ? find.byKey(const ValueKey('conversation-timeline'))
              : find.byKey(const ValueKey('task-detail-scroll')),
          matching: find.byType(Scrollable),
        );
        final scrollable = timeline.evaluate().isNotEmpty
            ? timeline.first
            : find.byType(Scrollable).last;
        final position = tester.state<ScrollableState>(scrollable).position;
        position.jumpTo(position.minScrollExtent);
        await tester.pump();
        await tester.scrollUntilVisible(target, 150, scrollable: scrollable);
      }
      await Scrollable.ensureVisible(tester.element(target), alignment: 0.3);
      await tester.pumpUntilUiSettled();
      if (target.hitTestable().evaluate().isNotEmpty) break;
    }
    expect(target.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  Future<void> tap(Finder target) async {
    await visible(target);
    await tester.tap(target);
    await tester.pumpUntilUiSettled();
    expect(tester.takeException(), isNull);
  }

  Future<void> key(String value) => tap(find.byKey(ValueKey(value)));
  Future<void> send(String value) async {
    await tester.enterText(
      find.byKey(const ValueKey('conversation-input')),
      value,
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    await tester.pumpUntilUiSettled();
    await key('send-text');
  }

  Future<ProviderContainer> enter(String name) async {
    await tester.pumpWidget(
      MigrationWorkbench(
        key: ValueKey(name),
        scenes: [workbenchScenes.singleWhere((s) => s.id == 'app')],
      ),
    );
    await key('scene-app');
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PhoneAgentApp)),
    );
    expect(container.read(appConfigProvider).apiBaseUri, isNull);
    await key('skill-restaurant_booking');
    await key('toggle-text');
    return container;
  }

  void checkAuth(ProviderContainer container) {
    final auth = container.read(sessionStoreProvider) as AuthScenario;
    expect(auth.sends, 0);
    expect(auth.submissions, isEmpty);
    expect(forbidden, isEmpty);
  }

  final single = await enter('single');
  final calls = single.read(shellCallPortsProvider);
  final singlePorts = single.read(shellConversationPortsProvider);
  await send('演练单路通话');
  expect(singlePorts.commands, hasLength(1));
  expect(find.byType(CallSessionPage), findsNothing);
  await visible(find.byType(CallConfirmationCard));
  await tester.pumpUntilUiSettled();
  await send('确认拨打');
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpUntilUiSettled();
  expect(find.byType(CallSessionPage), findsOneWidget);
  final singleId = singlePorts.commands.first.sessionId;
  final flow = calls.flow(singleId)!;
  await key('call-挂断');
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpUntilUiSettled();
  expect(find.byType(CallSessionPage), findsNothing);
  expect(flow.hangups, 1);
  final price = find.text('100积分');
  await visible(price);
  expect(find.byType(CallConfirmationCard), findsOneWidget);
  await capture('53-confirmation-single-billing');
  // Existing formal controller selection; this step tests history, not picker UI.
  await single
      .read(callModelControllerProvider.notifier)
      .select(
        single
            .read(callModelControllerProvider)
            .catalog!
            .models
            .firstWhere((model) => model.id == 'DOUBAO'),
      );
  await tester.pumpUntilUiSettled();
  await key('close-conversation');
  await key('tab-2');
  await key('conversation:$singleId');
  await key('toggle-text');
  expect(find.text('110积分'), findsNothing);
  await visible(price);
  expect(
    flow.commands.where((c) => c.actionId == 'confirm_call'),
    hasLength(1),
  );
  await capture('54-confirmation-single-restored');
  checkAuth(single);
  await key('workbench-home');

  final batch = await enter('batch');
  final ports = batch.read(shellConversationPortsProvider);
  await send('演练扩展批量确认');
  expect(find.byType(BatchConfirmationCard), findsOneWidget);
  expect(find.text('合成联系人5'), findsNothing);
  await visible(find.text('联系人检查'));
  await capture('55-confirmation-batch-audit');
  await key('batch-confirmation-toggle-contacts');
  await visible(find.text('合成联系人5'));
  await capture('56-confirmation-batch-expanded');
  await key('batch-confirmation-toggle-contacts');
  expect(find.text('合成联系人5'), findsNothing);
  final session = ports.commands.single.sessionId;
  final pending = (await ports.restore(
    session,
  )).pendingTool!.payload['toolCallId'];
  await key('close-conversation');
  await key('tab-2');
  await key('conversation:$session');
  expect(find.text('等待确认'), findsOneWidget);
  expect(ports.commands, hasLength(1));
  await visible(price);
  await capture('57-confirmation-batch-restored');
  await key('toggle-text');
  await send('确认');
  expect(ports.commands, hasLength(2));
  expect(ports.commands.last.pendingToolCallId, pending);
  expect(ports.commands.last.actionId, isNull);
  expect(find.byType(BatchConfirmationCard), findsOneWidget);
  expect(find.byType(CallConfirmationCard), findsNothing);
  expect(find.byType(CallSessionPage), findsNothing);
  await visible(find.text('已确认'));
  expect(find.text('已确认'), findsOneWidget);
  await key('close-conversation');
  await key('conversation:$session');
  await visible(find.text('已确认'));
  expect(find.text('已确认'), findsOneWidget);
  expect(ports.commands, hasLength(2));
  await visible(price);
  await capture('58-confirmation-batch-confirmed');
  checkAuth(batch);
  await key('workbench-home');
  await tester.pumpWidget(const SizedBox());
  await tester.pumpUntilUiSettled();
  expect(forbidden, isEmpty);
}
