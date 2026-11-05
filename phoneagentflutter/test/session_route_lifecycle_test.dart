import 'support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/call_models/presentation/pages/call_models_page.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/auth/presentation/pages/auth_page.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_route.dart';
import '../tool/previews/auth_scenario.dart';
import '../tool/previews/migration_workbench.dart';
import '../tool/previews/shell_conversation_ports.dart';
import '../tool/previews/workbench_catalog.dart';

void main() {
  for (final reject in [false, true]) {
    testWidgets(
      'active conversation released on ${reject ? 'rejection' : 'signout'}',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MigrationWorkbench(
            scenes: [workbenchScenes.singleWhere((s) => s.id == 'app')],
          ),
        );
        Future<void> key(String id) async {
          await tester.pumpUntilUiSettled();
          final target = find.byKey(ValueKey(id));
          await tester.ensureVisible(target);
          await tester.tap(target);
          await tester.pumpUntilUiSettled();
        }

        await key('scene-app');
        final container = ProviderScope.containerOf(
          tester.element(find.byType(PhoneAgentApp)),
        );
        final session = container.read(sessionControllerProvider.notifier);
        final credentials = session.credentials!;
        final auth = container.read(sessionStoreProvider) as AuthScenario;
        final agent = container.read(shellConversationPortsProvider);
        await key('skill-restaurant_booking');
        await key('toggle-text');
        await tester.enterText(
          find.byKey(const ValueKey('conversation-input')),
          '等待处理的合成消息',
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('send-text')));
        await tester.pump();
        expect(find.byType(ConversationRoute), findsOneWidget);
        final entry = tester
            .widget<ConversationRoute>(find.byType(ConversationRoute))
            .entry;
        final oldController = container.read(
          conversationControllerProvider(entry).notifier,
        );
        expect(agent.commands, hasLength(1));
        final leaving = reject
            ? session.rejectSession(credentials)
            : session.signOut();
        await tester.pumpUntilUiSettled();
        await leaving;
        expect(tester.takeException(), isNull);
        expect(find.byType(ConversationRoute), findsNothing);
        expect(find.byType(AuthPage), findsOneWidget);
        expect(auth.saved, isNull);
        expect(auth.sends, 0);
        expect(session.credentials, isNull);
        expect(agent.commands, hasLength(1));
        expect(oldController.mounted, isFalse);
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('已收到你的选择。'), findsNothing);
        await session.accept(
          const LoginOutcome(
            phone: '13800000000',
            accountId: 'synthetic-preview',
            accessToken: 'synthetic-relogin',
            inviteRequired: false,
          ),
        );
        await tester.pumpUntilUiSettled();
        expect(find.byType(ConversationRoute), findsNothing);
        expect(
          find.byKey(const ValueKey('homeVoiceModelChip')),
          findsOneWidget,
        );
        expect(container.read(appRouterProvider).canPop(), isFalse);
        expect(auth.sends, 0);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpUntilUiSettled();
      },
    );
  }

  testWidgets('token refresh preserves draft; expiry removes model sheet', (
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
    Future<void> tap(String id) async {
      await tester.tap(find.byKey(ValueKey(id)));
      await tester.pumpUntilUiSettled();
    }

    await tap('scene-app');
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PhoneAgentApp)),
    );
    final session = container.read(sessionControllerProvider.notifier);
    final router = container.read(appRouterProvider);
    await tap('skill-restaurant_booking');
    await tap('toggle-text');
    await tester.enterText(
      find.byKey(const ValueKey('conversation-input')),
      '未发送草稿',
    );
    await tester.pumpUntilUiSettled();
    final entry = tester
        .widget<ConversationRoute>(find.byType(ConversationRoute))
        .entry;
    final controller = container.read(
      conversationControllerProvider(entry).notifier,
    );
    final before = session.credentials!;
    expect(await session.replaceToken(before, 'synthetic-refreshed'), isTrue);
    await tester.pumpUntilUiSettled();
    expect(session.credentials!.epoch, before.epoch);
    expect(container.read(appRouterProvider), same(router));
    expect(
      container.read(conversationControllerProvider(entry).notifier),
      same(controller),
    );
    expect(find.text('未发送草稿'), findsOneWidget);
    await tap('conversation-model');
    expect(find.byType(CallModelsPage), findsOneWidget);
    final rejected = session.rejectSession(session.credentials!);
    await tester.pumpUntilUiSettled();
    await rejected;
    expect(find.byType(CallModelsPage), findsNothing);
    expect(find.text('未发送草稿'), findsNothing);
    expect(find.byType(AuthPage), findsOneWidget);
    expect(controller.mounted, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpUntilUiSettled();
  });
}
