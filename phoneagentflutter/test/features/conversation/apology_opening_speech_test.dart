import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/conversation_precheck_providers.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_voice_host.dart';
import '../../support/apology_provider_fixture.dart';

void main() {
  for (final apology in [true, false]) {
    testWidgets('actual voice host opening sequence: apology=$apology', (
      tester,
    ) async {
      final entry = ConversationEntry(
        sessionId: 'speech',
        skillId: apology ? 'apology_master' : 'restaurant',
        opening: '原有任务开场。',
      );
      final fixture = ApologyProviderFixture(entry);
      addTearDown(fixture.dispose);
      await fixture.open(tester);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: fixture.container,
          child: MaterialApp(
            home: Scaffold(
              body: ConversationVoiceHost(
                entry: entry,
                builder: (_) => const Text('会话'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      if (apology) {
        expect(
          fixture.players,
          isEmpty,
          reason: 'pending apology cannot narrate old entry opening',
        );
        await fixture.complete(tester);
        await tester.pump();
        expect(
          fixture.players.single.sentences.single,
          contains('道歉需要使用您的克隆音色'),
        );
        final precheck = fixture.container.read(
          conversationPrecheckProvider(entry),
        );
        precheck.simulateWeak(true);
        await tester.pump();
        expect(fixture.players, hasLength(1));
      } else {
        expect(fixture.players.single.sentences, ['原有任务开场。']);
      }
      final controller = fixture.container.read(
        conversationControllerProvider(entry).notifier,
      );
      controller.close();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      expect(tester.takeException(), isNull);
    });
  }
}
