import 'support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/features/attachments/presentation/widgets/agent_document_host.dart';
import 'package:phone_agent/features/attachments/presentation/widgets/native_agent_document_sheet.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';

import '../tool/previews/shell_agent_document_ports.dart';
import '../tool/previews/shell_preview.dart';
import '../tool/previews/shell_conversation_ports.dart';

void main() {
  test(
    'document continuation never captures another ordinary session',
    () async {
      final delegate = ShellConversationPorts();
      final ports = ShellAgentDocumentPorts(delegate);
      AgentCommand command(String session, String text) => AgentCommand(
        sessionId: session,
        userId: 'synthetic',
        commandId: '$session:$text',
        idempotencyKey: '$session:$text',
        traceId: 'synthetic',
        message: text,
      );
      await ports.start(command('document', 'ui-document')).events.toList();
      final ordinary = await ports
          .start(command('ordinary', '继续'))
          .events
          .toList();
      expect(ordinary.any((event) => event.text == 'MOCK 继续对话成功。'), false);
      expect(ports.commands, hasLength(1));
      final continuation = await ports
          .start(command('document', '继续'))
          .events
          .toList();
      expect(continuation.any((event) => event.text == 'MOCK 继续对话成功。'), true);
      expect(ports.commands, hasLength(2));
      ports.close();
      delegate.close();
    },
  );
  testWidgets(
    'opt-in full App Agent document cancel stays in conversation',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const ShellPreviewPage());
      await tester.pumpUntilUiSettled();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PhoneAgentApp)),
      );
      final ports = container.read(shellAgentDocumentPortsProvider);
      await tester.tap(find.byKey(const ValueKey('skill-restaurant_booking')));
      await tester.pumpUntilUiSettled();
      await tester.tap(find.byKey(const ValueKey('toggle-text')));
      await tester.pumpUntilUiSettled();
      await tester.enterText(
        find.byKey(const ValueKey('conversation-input')),
        'ui-document',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('send-text')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpUntilUiSettled();
      expect(ports.commands, hasLength(1));
      expect(find.byType(NativeAgentDocumentSheet), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('agent-document-pick')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('正在解析文件'), findsOneWidget);
      final barrier = find
          .descendant(
            of: find.byType(AgentDocumentHost),
            matching: find.byType(ModalBarrier),
          )
          .last;
      await tester.tapAt(tester.getRect(barrier).topLeft + const Offset(8, 8));
      await tester.pump();
      await tester.pump(const Duration(seconds: 11));
      await tester.pumpUntilUiSettled();
      expect(find.byType(NativeAgentDocumentSheet), findsNothing);
      expect(
        ports.commands.where(
          (command) => command.actionId == 'submit_document',
        ),
        hasLength(1),
      );
      expect(ports.commands.last.actionPayload!['status'], 'USER_CANCELLED');
      expect(find.byKey(const ValueKey('conversation-input')), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('conversation-input')),
        '继续',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('send-text')));
      await tester.pumpUntilUiSettled();
      expect(ports.commands.last.message, '继续');
      expect(find.text('MOCK 继续对话成功。'), findsOneWidget);
      expect(find.text('请选择餐厅'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    skip: !shellAgentDocumentEnabled,
  );
}
