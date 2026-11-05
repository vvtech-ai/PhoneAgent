import 'support/pump_ui_transitions.dart';
import 'package:phone_agent/features/contacts/presentation/pages/contact_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/contact_providers.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/app/dialer_providers.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/contacts/presentation/pages/contacts_route.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_route.dart';
import '../tool/previews/auth_scenario.dart';
import '../tool/previews/migration_workbench.dart';
import '../tool/previews/shell_contacts_preview.dart';
import '../tool/previews/shell_conversation_ports.dart';
import '../tool/previews/workbench_catalog.dart';

void main() {
  testWidgets(
    'unsupported normal Web path does not read injected device ports',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contactsSharedFlowEnabledProvider.overrideWithValue(false),
            contactsControllerProvider.overrideWith(
              (ref) => throw StateError('must not read contacts'),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: ContactsRoute())),
        ),
      );
      await tester.pumpUntilUiSettled();
      expect(find.text('浏览器无法读取手机系统通讯录。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 430.0]) {
    testWidgets(
      'contact detail to formal task and restored conversation $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MigrationWorkbench(
            scenes: [workbenchScenes.singleWhere((scene) => scene.id == 'app')],
          ),
        );
        Future<void> tap(Finder target) async {
          await tester.pumpUntilUiSettled();
          if (target.evaluate().isEmpty) {
            await tester.scrollUntilVisible(
              target,
              160,
              scrollable: find.byType(Scrollable).last,
            );
          }
          await Scrollable.ensureVisible(
            tester.element(target),
            alignment: 0.35,
          );
          await tester.pumpUntilUiSettled();
          await tester.tap(target);
          await tester.pumpUntilUiSettled();
          expect(tester.takeException(), isNull);
        }

        Future<void> key(String value) => tap(find.byKey(ValueKey(value)));
        Future<void> text(String value) => tap(find.text(value));
        Future<void> backToContacts() => tap(find.byTooltip('返回联系人'));

        await key('scene-app');
        final container = ProviderScope.containerOf(
          tester.element(find.byType(PhoneAgentApp)),
        );
        final auth = container.read(sessionStoreProvider) as AuthScenario;
        final ports = container.read(shellContactsPortsProvider);
        expect(container.read(systemDialerProvider), same(ports));
        await key('tab-1');
        expect(find.text('浏览器无法读取手机系统通讯录。'), findsNothing);
        await tap(find.bySemanticsLabel('演示联系人，2025550101'));
        await text('编辑');
        await tester.enterText(
          find.byKey(const ValueKey('contact-remark-input')),
          '只在下午联系',
        );
        await text('保存');
        expect(find.text('只在下午联系'), findsOneWidget);
        await text('编辑');
        await tester.enterText(
          find.byKey(const ValueKey('contact-remark-input')),
          '取消的修改',
        );
        await text('取消');
        expect(find.text('取消的修改'), findsNothing);
        expect(find.text('只在下午联系'), findsOneWidget);
        await backToContacts();
        await tap(find.bySemanticsLabel('演示联系人，2025550102'));
        expect(find.text('暂无备注'), findsOneWidget);
        final dialDraft = container.read(dialerControllerProvider);
        await text('拨打电话');
        expect(container.read(dialerControllerProvider), same(dialDraft));
        expect(ports.openedNumbers, ['2025550102']);
        expect(find.byKey(const ValueKey('dial-country')), findsNothing);
        expect(find.byType(ContactDetailPage), findsOneWidget);
        expect(find.byTooltip('返回联系人'), findsOneWidget);

        await text('发起任务');
        expect(find.text('同声传译'), findsNothing);
        expect(find.text('道歉'), findsNothing);
        await text('订餐厅');
        expect(find.byType(ConversationRoute), findsOneWidget);
        final opening = find.textContaining('想订演示联系人');
        if (opening.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            opening,
            -160,
            scrollable: find
                .descendant(
                  of: find.byKey(const ValueKey('conversation-timeline')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
        }
        expect(opening, findsOneWidget);
        await key('toggle-text');
        await tester.enterText(
          find.byKey(const ValueKey('conversation-input')),
          '明晚六点两人',
        );
        await key('send-text');
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpUntilUiSettled();
        final agent =
            container.read(agentGatewayProvider) as ShellConversationPorts;
        expect(agent.commands.length, 1);
        expect(agent.commands.single.selectedContact?.phone, '2025550102');
        expect(agent.commands.single.initialSkillId, 'restaurant_booking');
        final id = agent.commands.single.sessionId;
        await key('close-conversation');
        expect(find.text('2025550102'), findsOneWidget);
        await backToContacts();
        await key('tab-2');
        await key('conversation:$id');
        expect(find.text('明晚六点两人'), findsOneWidget);
        expect(agent.commands.length, 1, reason: '恢复不能重发首轮/指定联系人');
        await tap(find.textContaining('合成餐厅甲'));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpUntilUiSettled();
        expect(agent.commands.length, 2);
        expect(agent.commands.last.selectedContact, isNull);
        expect(find.text('已收到你的选择。'), findsOneWidget);
        await key('close-conversation');
        await key('tab-1');
        await tap(find.bySemanticsLabel('演示联系人，2025550101'));
        expect(find.text('只在下午联系'), findsOneWidget);
        await backToContacts();
        await key('tab-3');
        await key('settings-logout');
        await text('退出');
        await tester.enterText(
          find.byKey(const ValueKey('loginPhone')),
          '13800000000',
        );
        await tester.enterText(find.byKey(const ValueKey('loginCode')), '123456');
        await key('loginAgreement');
        await key('loginBtn');
        await key('tab-1');
        await tap(find.bySemanticsLabel('演示联系人，2025550101'));
        expect(find.text('暂无备注'), findsOneWidget);
        expect(container.read(shellContactsPortsProvider), isNot(same(ports)));
        expect(
          container.read(shellContactsPortsProvider).openedNumbers,
          isEmpty,
        );
        expect(auth.sends, 0);
        await key('workbench-home');
        await key('scene-app');
        await key('tab-1');
        await tap(find.bySemanticsLabel('演示联系人，2025550101'));
        expect(find.text('暂无备注'), findsOneWidget);
        await key('workbench-home');
        await tester.pumpWidget(const SizedBox());
        await tester.pumpUntilUiSettled();
      },
    );
  }
}
