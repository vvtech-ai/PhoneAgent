import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/conversation_providers.dart'
    show taskRepositoryProvider;
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_route.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/home/domain/home_config.dart';
import 'package:phone_agent/features/settings/domain/network_availability.dart';
import '../tool/previews/shell_catalog_fakes.dart';
import '../tool/previews/shell_conversation_fakes.dart';
import 'support/apology_provider_fixture.dart';
import 'support/initialized_identity.dart';
import 'support/pump_ui_transitions.dart';

class _Home extends FakeHomeRepository {
  @override
  Future<HomeConfig> load() async {
    final value = await super.load();
    return HomeConfig(value.version, value.slogans, [
      for (final card in value.cards)
        if (card.id == 'apology')
          const HomeCard(
            id: 'apology',
            title: '道歉',
            subtitle: '合成目录已开放',
            status: HomeCardStatus.enabled,
            action: HomeAction.skill,
            skillId: 'apology_master',
            opening: '旧道歉开场。',
          )
        else
          card,
    ]);
  }
}

void main() {
  testWidgets(
    '320 actual shell apology entry waits, retries and opens one consent card',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final fixture = ApologyProviderFixture(
        const ConversationEntry(sessionId: 'unused'),
        extra: [
          ...initializedIdentityOverrides(),
          appConfigProvider.overrideWithValue(
            AppConfig.parse(environment: 'local', apiBaseUrl: ''),
          ),
          homeRepositoryProvider.overrideWithValue(_Home()),
          taskRepositoryProvider.overrideWithValue(OfflineTasks()),
        ],
      );
      addTearDown(fixture.dispose);
      fixture.network.initial.complete(NetworkAvailability.available);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: fixture.container,
          child: const PhoneAgentApp(),
        ),
      );
      await tester.pumpUntilUiSettled();
      final card = find.byKey(const ValueKey('skill-apology'));
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.byType(ConversationRoute), findsOneWidget);
      final route = tester.widget<ConversationRoute>(
        find.byType(ConversationRoute),
      );
      expect(route.entry.skillId, 'apology_master');
      expect(find.textContaining('道歉需要使用您的克隆音色'), findsNothing);
      expect(fixture.players, isEmpty);
      fixture.network.changes.add(NetworkAvailability.unavailable);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('网络连接不可用'), findsWidgets);
      expect(find.textContaining('道歉需要使用您的克隆音色'), findsNothing);
      fixture.network.changes.add(NetworkAvailability.available);
      await tester.pump();
      for (final ms in [350, 350, 500]) {
        await tester.pump(Duration(milliseconds: ms));
      }
      await tester.pump();
      expect(find.textContaining('道歉需要使用您的克隆音色'), findsOneWidget);
      expect(fixture.players.single.sentences.single, contains('道歉需要使用您的克隆音色'));
      expect(fixture.gateway.commands, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('close-conversation')));
      await tester.pumpUntilUiSettled();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpUntilUiSettled();
    },
  );
}
