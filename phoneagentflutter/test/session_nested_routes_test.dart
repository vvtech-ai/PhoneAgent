import 'support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/auth/presentation/pages/auth_page.dart';
import '../tool/previews/migration_workbench.dart';
import '../tool/previews/workbench_catalog.dart';

void main() {
  for (final destination in [
    'settings',
    'contact',
    'contact-task',
    'translation',
  ]) {
    testWidgets('identity rejection clears $destination navigation', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MigrationWorkbench(
          scenes: [workbenchScenes.singleWhere((s) => s.id == 'app')],
        ),
      );
      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpUntilUiSettled();
      }

      Future<void> key(String id) => tap(find.byKey(ValueKey(id)));
      await key('scene-app');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PhoneAgentApp)),
      );
      final session = container.read(sessionControllerProvider.notifier);
      switch (destination) {
        case 'settings':
          await key('tab-3');
          await key('settings-originalAudio');
        case 'contact' || 'contact-task':
          await key('tab-1');
          await tap(find.bySemanticsLabel('演示联系人，2025550101'));
          if (destination == 'contact-task') {
            await tap(find.text('发起任务'));
            await tap(find.text('订餐厅'));
            await key('toggle-text');
            await tester.enterText(
              find.byKey(const ValueKey('conversation-input')),
              '合成处理中',
            );
            await tester.tap(find.byKey(const ValueKey('send-text')));
            await tester.pump();
          }
        case 'translation':
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('skill-simultaneous_interpretation')),
            250,
          );
          await key('skill-simultaneous_interpretation');
      }
      expect(container.read(appRouterProvider).canPop(), isTrue);
      final logout = session.rejectSession(session.credentials!);
      await tester.pumpUntilUiSettled();
      await logout;
      expect(find.byType(AuthPage), findsOneWidget);
      expect(container.read(appRouterProvider).canPop(), isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpUntilUiSettled();
    });
  }
}
