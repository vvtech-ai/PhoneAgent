import 'support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/calls/domain/call_session.dart';
import 'package:phone_agent/features/calls/presentation/pages/call_session_page.dart';
import '../tool/previews/auth_scenario.dart';
import '../tool/previews/migration_workbench.dart';
import '../tool/previews/shell_call_preview.dart';
import '../tool/previews/shell_conversation_ports.dart';
import '../tool/previews/workbench_catalog.dart';

void main() {
  for (final scenario in [(320.0, false), (430.0, false), (430.0, true)]) {
    final (width, attemptBack) = scenario;
    testWidgets('full App call controls $width back=$attemptBack', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final previousHitTest = WidgetController.hitTestWarningShouldBeFatal;
      WidgetController.hitTestWarningShouldBeFatal = true;
      addTearDown(
        () => WidgetController.hitTestWarningShouldBeFatal = previousHitTest,
      );
      final storageCalls = <String>[];
      final nativeCalls = <String>[];
      const storage = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(storage, (call) async {
        storageCalls.add(call.method);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(storage, null));
      for (final name in [
        'phone_agent/pcm_output',
        'com.vvtech.phone_agent/system_dialer',
      ]) {
        final channel = MethodChannel(name);
        messenger.setMockMethodCallHandler(channel, (call) async {
          nativeCalls.add('$name:${call.method}');
          throw StateError('Real device port forbidden');
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      }
      await tester.pumpWidget(
        MigrationWorkbench(
          scenes: [workbenchScenes.singleWhere((s) => s.id == 'app')],
        ),
      );
      Future<void> key(String value) async {
        await tester.pumpUntilUiSettled();
        final finder = find.byKey(ValueKey(value));
        if (finder.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            finder,
            150,
            scrollable: find.byType(Scrollable).last,
          );
        }
        await Scrollable.ensureVisible(tester.element(finder), alignment: 0.35);
        await tester.pumpUntilUiSettled();
        await tester.tap(finder);
        await tester.pumpUntilUiSettled();
        expect(tester.takeException(), isNull);
      }

      Future<void> text(String value) async {
        await tester.tap(find.text(value));
        await tester.pumpUntilUiSettled();
      }

      await tester.pumpUntilUiSettled();
      await key('scene-app');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PhoneAgentApp)),
      );
      final calls = container.read(shellCallPortsProvider);
      final conversations = container.read(shellConversationPortsProvider);
      final auth = container.read(sessionStoreProvider) as AuthScenario;
      await text('订餐厅');
      await key('toggle-text');
      await tester.enterText(
        find.byKey(const ValueKey('conversation-input')),
        '演练单路通话',
      );
      await key('send-text');
      expect(find.byType(CallSessionPage), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('conversation-input')),
        '确认拨打',
      );
      await key('send-text');
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpUntilUiSettled();
      expect(find.byType(CallSessionPage), findsOneWidget);
      void expectHiddenInputUnfocused() {
        expect(
          tester
              .widgetList<EditableText>(
                find.byType(EditableText, skipOffstage: false),
              )
              .map((input) => input.focusNode.hasFocus),
          everyElement(isFalse),
        );
      }

      expectHiddenInputUnfocused();
      final id = conversations.commands.first.sessionId;
      final flow = calls.flow(id)!;
      expect(
        flow.commands.where((c) => c.actionId == 'confirm_call').length,
        1,
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpUntilUiSettled();
      await key('call-开始监听');
      expect(calls.monitor.tickets, 1);
      calls.monitor.pcm();
      await tester.pumpUntilUiSettled();
      expect(calls.monitor.receivedBytes, 3200);
      await key('call-音源，听筒');
      await key('source-speaker');
      expect(calls.monitor.output!.selected, 'speaker');
      expectHiddenInputUnfocused();
      await key('call-音源，扬声器');
      final barrier = tester.getRect(find.byType(ModalBarrier).last);
      await tester.tapAt(Offset(barrier.center.dx, barrier.top + 24));
      await tester.pumpUntilUiSettled();
      expect(calls.monitor.output!.selected, 'speaker');
      expectHiddenInputUnfocused();
      await key('call-停止监听');
      expect(calls.monitor.output!.enabled, isFalse);
      await key('call-开始监听');
      expect(calls.monitor.tickets, 1);
      if (attemptBack) {
        await Navigator.of(
          tester.element(find.byType(CallSessionPage)),
        ).maybePop();
        await tester.pumpUntilUiSettled();
        expect(find.byType(CallSessionPage), findsOneWidget);
        expect(flow.hangups, 0);
        expect(flow.ended, isFalse);
        expect(calls.monitor.socket!.closed, isFalse);
        expect(calls.monitor.output!.stopped, isFalse);
        calls.monitor.pcm();
        await tester.pumpUntilUiSettled();
        expect(calls.monitor.receivedBytes, 6400);
      }
      await key('call-挂断');
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpUntilUiSettled();
      expect(flow.hangups, 1);
      expect(find.byType(CallSessionPage), findsNothing);
      expect(find.text('MOCK：单路任务已完成，已返回对话。'), findsOneWidget);
      // Retained confirmation prose may put its frozen billing above the cache.
      if (find.text('100积分').evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          find.text('100积分'),
          150,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('conversation-timeline')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpUntilUiSettled();
      }
      expect(find.text('100积分'), findsOneWidget);
      expect(find.text('请确认以上任务内容，是否现在拨打？'), findsOneWidget);
      await container
          .read(callModelControllerProvider.notifier)
          .select(
            container
                .read(callModelControllerProvider)
                .catalog!
                .models
                .firstWhere((model) => model.id == 'DOUBAO'),
          );
      await tester.pumpUntilUiSettled();
      expect(find.text('100积分'), findsOneWidget);
      expect(find.text('110积分'), findsNothing);
      await key('close-conversation');
      await key('tab-2');
      await key('conversation:$id');
      final price = find.text('100积分');
      if (price.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          price,
          150,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('conversation-timeline')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
      }
      expect(find.text('100积分'), findsOneWidget);
      expect(find.byType(CallSessionPage), findsNothing);
      expect(find.text('MOCK：单路任务已完成，已返回对话。'), findsOneWidget);
      expect(
        flow.commands.where((c) => c.actionId == 'confirm_call').length,
        1,
      );
      expect(calls.monitor.socket!.closed, isTrue);
      expect(auth.sends, 0);
      await key('toggle-text');
      await tester.enterText(
        find.byKey(const ValueKey('conversation-input')),
        '再补充一个要求',
      );
      await key('send-text');
      expect(find.text('已收到补充要求，当前为 MOCK，未拨号。'), findsOneWidget);
      expect(find.byType(CallSessionPage), findsNothing);
      expect(flow.commands.length, 2);
      await key('workbench-home');
      await tester.pumpUntilUiSettled();
      expect(storageCalls, isEmpty);
      expect(nativeCalls, isEmpty);
      await expectLater(
        calls.status(CallSessionTarget(taskId: id)),
        throwsStateError,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpUntilUiSettled();
    });
  }
}
