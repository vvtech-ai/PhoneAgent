import '../../support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/features/contacts/data/preview_contact_agent.dart';
import 'package:phone_agent/features/contacts/domain/contact_skill_opening.dart';
import 'package:phone_agent/features/contacts/presentation/pages/contact_task_route.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_page.dart';

void main() {
  test(
    'selected contact goes in first user turn only, never blank/repeated',
    () async {
      final gateway = _Gateway();
      final c = ConversationController(
        entry: const ConversationEntry(
          sessionId: 'synthetic',
          skillId: 'restaurant_booking',
          selectedContact: SelectedContactContext(
            name: ' 演示联系人 ',
            phone: '2025550101',
          ),
        ),
        accountId: 'synthetic',
        gateway: gateway,
        history: PreviewContactAgent(),
      );
      addTearDown(c.dispose);
      expect(c.send(' '), isFalse);
      expect(c.send('明天三人'), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(gateway.commands.first.toJson()['selectedContact'], {
        'source': 'CONTACT_DETAIL',
        'name': '演示联系人',
        'phone': '2025550101',
      });
      expect(c.send('晚上六点'), isTrue);
      expect(
        gateway.commands.last.toJson().containsKey('selectedContact'),
        isFalse,
      );
    },
  );
  test('skill opening follows fixed v65 with fallback', () {
    expect(
      contactSkillOpening('restaurant_booking', ' 演示餐厅 ', 'fallback'),
      '想订演示餐厅？告诉我时间和人数就行，有其他要求也可以一起说。',
    );
    expect(
      contactSkillOpening('meeting_notification', '演示甲', ''),
      contains('演示甲'),
    );
    expect(
      contactSkillOpening('business_event_invitation', '演示甲', ''),
      contains('以谁的名义'),
    );
    expect(contactSkillOpening('custom', '演示甲', '后端开场白'), '后端开场白');
    expect(contactSkillOpening('restaurant_booking', ' ', '后端开场白'), '后端开场白');
  });
  testWidgets(
    'MOCK contact task shares unified page without account or real gateway',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            agentGatewayProvider.overrideWith(
              (ref) => throw StateError('must not use real gateway'),
            ),
            currentAccountIdProvider.overrideWith(
              (ref) => throw StateError('must not read account'),
            ),
          ],
          child: const MaterialApp(
            home: ContactTaskRoute(
              preview: true,
              entry: ConversationEntry(
                sessionId: 'mock-contact',
                opening: '演示开场白',
              ),
            ),
          ),
        ),
      );
      await tester.pumpUntilUiSettled();
      expect(find.text('演示开场白'), findsOneWidget);
      final page = tester.widget<ConversationPage>(
        find.byType(ConversationPage),
      );
      expect(page.state.voiceMode, isTrue);
      page.onToggle();
      await tester.pump();
      final textPage = tester.widget<ConversationPage>(
        find.byType(ConversationPage),
      );
      expect(textPage.state.voiceMode, isFalse);
      textPage.onSend('明晚三人');
      await tester.pumpUntilUiSettled();
      Future<void> read(Finder target) async {
        final scrollable = find
            .descendant(
              of: find.byKey(const ValueKey('conversation-timeline')),
              matching: find.byType(Scrollable),
            )
            .first;
        if (target.evaluate().isEmpty) {
          final position = tester.state<ScrollableState>(scrollable).position;
          position.jumpTo(position.minScrollExtent);
          await tester.pump();
          await tester.scrollUntilVisible(target, 150, scrollable: scrollable);
        }
        await Scrollable.ensureVisible(tester.element(target));
        await tester.pumpUntilUiSettled();
        expect(target, findsOneWidget);
        expect(
          tester
              .getRect(target)
              .overlaps(
                tester.getRect(
                  find.byKey(const ValueKey('conversation-timeline')),
                ),
              ),
          isTrue,
        );
      }

      await read(find.text('明晚三人'));
      await read(find.textContaining('MOCK：已收到您的文字'));
      await read(find.textContaining('共享查询找到演示联系人'));
      final candidatePage = tester.widget<ConversationPage>(
        find.byType(ConversationPage),
      );
      final options = candidatePage.state.messages
          .where((m) => m.options.isNotEmpty)
          .single;
      expect(options.options, hasLength(2));
      expect(options.options[1].detail, contains('2025550102'));
      candidatePage.onChoose(options.id, 1);
      await tester.pumpUntilUiSettled();
      await read(find.text('第 2 个'));
      await read(find.textContaining('候选选择已回传“第 2 个”'));
      expect(tester.takeException(), isNull);
    },
  );
}

class _Gateway implements AgentGateway {
  final commands = <AgentCommand>[];
  @override
  AgentRun start(AgentCommand command) {
    commands.add(command);
    return AgentRun(Stream.value(const AgentEvent(AgentEventKind.done)), () {});
  }
}
