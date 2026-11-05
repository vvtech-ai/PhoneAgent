import 'support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/batch_confirmation_card.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/call_confirmation_card.dart';
import '../tool/previews/auth_scenario.dart';
import '../tool/previews/migration_workbench.dart';
import '../tool/previews/shell_conversation_ports.dart';
import '../tool/previews/workbench_catalog.dart';

void main() {
  for (final width in [320.0, 430.0]) {
    testWidgets(
      'structured batch pending restore, expansion and reply $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final calls = <String>[];
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        for (final name in [
          'plugins.it_nomads.com/flutter_secure_storage',
          'phone_agent/legacy_confirmation_billing',
          'com.vvtech.phone_agent/system_dialer',
        ]) {
          final channel = MethodChannel(name);
          messenger.setMockMethodCallHandler(channel, (call) async {
            calls.add('$name:${call.method}');
            throw StateError('Real port forbidden');
          });
          addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        }
        await tester.pumpWidget(
          MigrationWorkbench(
            scenes: [workbenchScenes.singleWhere((s) => s.id == 'app')],
          ),
        );
        Future<void> tap(Finder finder) async {
          await tester.pumpUntilUiSettled();
          await tester.ensureVisible(finder);
          await tester.pumpUntilUiSettled();
          await tester.tap(finder);
          await tester.pumpUntilUiSettled();
          expect(tester.takeException(), isNull);
        }

        Future<void> key(String value) => tap(find.byKey(ValueKey(value)));
        await key('scene-app');
        final container = ProviderScope.containerOf(
          tester.element(find.byType(PhoneAgentApp)),
        );
        final ports = container.read(shellConversationPortsProvider);
        final auth = container.read(sessionStoreProvider) as AuthScenario;
        await key('skill-restaurant_booking');
        await key('toggle-text');
        await tester.enterText(
          find.byKey(const ValueKey('conversation-input')),
          '演练扩展批量确认',
        );
        await key('send-text');
        expect(find.byType(BatchConfirmationCard), findsOneWidget);
        expect(find.text('合成联系人5'), findsNothing);
        expect(find.text('联系人检查'), findsOneWidget);
        await key('batch-confirmation-toggle-contacts');
        expect(find.text('合成联系人5'), findsOneWidget);
        await key('batch-confirmation-toggle-contacts');
        expect(find.text('合成联系人5'), findsNothing);
        final session = ports.commands.single.sessionId;
        final pending = (await ports.restore(
          session,
        )).pendingTool!.payload['toolCallId'];
        await key('close-conversation');
        await key('tab-2');
        await key('conversation:$session');
        expect(find.byType(BatchConfirmationCard), findsOneWidget);
        expect(find.text('等待确认'), findsOneWidget);
        expect(find.text('100积分'), findsOneWidget);
        expect(ports.commands.length, 1);
        await key('toggle-text');
        await tester.enterText(
          find.byKey(const ValueKey('conversation-input')),
          '确认',
        );
        await key('send-text');
        expect(ports.commands.length, 2);
        expect(ports.commands.last.pendingToolCallId, pending);
        expect(ports.commands.last.actionId, isNull);
        expect(find.byType(BatchConfirmationCard), findsOneWidget);
        expect(find.byType(CallConfirmationCard), findsNothing);
        expect(find.text('已确认'), findsOneWidget);
        expect(find.text('100积分'), findsOneWidget);
        await key('close-conversation');
        await key('conversation:$session');
        expect(find.text('已确认'), findsOneWidget);
        expect(ports.commands.length, 2);
        expect(auth.sends, 0);
        await key('workbench-home');
        expect(calls, isEmpty);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpUntilUiSettled();
      },
    );
  }
}
