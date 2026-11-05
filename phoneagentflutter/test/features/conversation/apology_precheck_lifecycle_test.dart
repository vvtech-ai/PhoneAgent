import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/conversation_precheck_providers.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/settings/domain/network_availability.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import '../../../tool/previews/shell_conversation_fakes.dart';
import '../../support/apology_provider_fixture.dart';

class _PinnedHistory extends OfflineHistory {
  @override
  Future<RestoredConversation> restore(String sessionId) async {
    final value = await super.restore(sessionId);
    return RestoredConversation(
      ConversationDetail(
        sessionId: sessionId,
        title: '道歉历史',
        status: 'ACTIVE',
        pinnedSkillId: 'apology_master',
        taskCallModelId: 'QWEN_OMNI_PLUS',
      ),
      ledger: value.ledger,
    );
  }
}

void main() {
  const entry = ConversationEntry(
    sessionId: 'synthetic-apology-entry',
    skillId: 'apology_master',
  );
  testWidgets(
    'already complete precheck callback waits until speech and OCR owner are initialized',
    (tester) async {
      final fixture = ApologyProviderFixture(entry);
      addTearDown(fixture.dispose);
      fixture.container.read(sessionControllerProvider);
      await tester.pump();
      final keep = fixture.container.listen(
        conversationPrecheckProvider(entry),
        (_, __) {},
      );
      addTearDown(keep.close);
      await fixture.complete(tester);
      expect(keep.read().presentation.visible, isFalse);
      await fixture.open(tester);
      final controller = fixture.container.read(
        conversationControllerProvider(entry).notifier,
      );
      expect(controller.state.messages.single.text, contains('道歉需要使用您的克隆音色'));
      expect(controller.speech, isNotNull);
      await controller.attachments!.pick(controller.ocrBoundary.sourceAnchor);
      expect(fixture.picker.picks, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'restored pinned apology never repeats consent on precheck completion',
    (tester) async {
      const restored = ConversationEntry(sessionId: 'restored', restore: true);
      final fixture = ApologyProviderFixture(
        restored,
        history: _PinnedHistory(),
      );
      addTearDown(fixture.dispose);
      await fixture.open(tester);
      final controller = fixture.container.read(
        conversationControllerProvider(restored).notifier,
      );
      expect(controller.apology!.voice.prompt, isNull);
      expect(controller.apology!.voice.modelId, 'QWEN_OMNI_PLUS');
      // History does not need the new-entry precheck subscription.
      final keep = fixture.container.listen(
        conversationPrecheckProvider(restored),
        (_, __) {},
      );
      addTearDown(keep.close);
      await fixture.complete(tester);
      expect(controller.apology!.voice.prompt, isNull);
      expect(
        controller.state.messages.any((m) => m.text.contains('道歉需要使用您的克隆音色')),
        isFalse,
      );
    },
  );
  testWidgets(
    'formal apology waits for precheck then opens once and preserves OCR lifetime',
    (tester) async {
      final fixture = ApologyProviderFixture(entry);
      addTearDown(fixture.dispose);
      await fixture.open(tester);
      final container = fixture.container;
      final controller = container.read(
        conversationControllerProvider(entry).notifier,
      );
      expect(controller.state.messages, isEmpty);
      expect(controller.apology!.voice.prompt, isNull);
      controller.send('确认使用');
      controller.send('检测前不能缓存后提交这句话');
      expect(
        fixture.api.requests.where((r) => r.uri.path.contains('voice-clone')),
        isEmpty,
      );
      await fixture.complete(tester);
      expect(
        container
            .read(conversationPrecheckProvider(entry))
            .presentation
            .visible,
        isFalse,
      );
      expect(controller.state.messages.single.text, contains('道歉需要使用您的克隆音色'));
      final identity = controller.state.activeOptionsId;
      expect(identity, startsWith('local:apology:'));
      expect(controller.speech, isNotNull);
      expect(fixture.gateway.commands, isEmpty);
      fixture.network.changes.add(NetworkAvailability.available);
      await tester.pump();
      expect(controller.state.activeOptionsId, identity);
      expect(controller.state.messages, hasLength(1));
      fixture.api.data = {
        'models': [
          {
            'modelId': 'QWEN_OMNI_PLUS',
            'displayName': 'Qwen',
            'available': true,
            'cloneEntitled': true,
            'current': {
              'modelId': 'QWEN_OMNI_PLUS',
              'status': 'READY',
              'usable': true,
              'providerAssetId': 'synthetic',
              'active': true,
            },
          },
        ],
      };
      controller.send('确认使用');
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 1));
      }
      expect(controller.apology!.voice.blocked, isFalse);
      expect(
        fixture.gateway.commands,
        isEmpty,
        reason:
            'input before environment completion must never be held for later submission',
      );
      await controller.attachments!.pick(controller.ocrBoundary.sourceAnchor);
      expect(fixture.picker.picks, 1);
      controller.close();
      await controller.attachments!.pick(controller.ocrBoundary.sourceAnchor);
      expect(fixture.picker.picks, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'failed environment cannot consume consent and retry completion starts once',
    (tester) async {
      final fixture = ApologyProviderFixture(entry);
      addTearDown(fixture.dispose);
      await fixture.open(tester);
      final controller = fixture.container.read(
        conversationControllerProvider(entry).notifier,
      );
      fixture.network.initial.complete(NetworkAvailability.unavailable);
      await tester.pump(const Duration(seconds: 3));
      expect(controller.state.messages, isEmpty);
      controller.send('确认使用');
      expect(controller.apology!.voice.prompt, isNull);
      fixture.network.changes.add(NetworkAvailability.available);
      await tester.pump();
      for (final ms in [350, 350, 500]) {
        await tester.pump(Duration(milliseconds: ms));
      }
      expect(controller.state.messages.single.text, contains('道歉需要使用您的克隆音色'));
      fixture.network.changes.add(NetworkAvailability.available);
      await tester.pump();
      expect(controller.state.messages, hasLength(1));
      expect(
        fixture.api.requests.where((r) => r.uri.path.contains('voice-clone')),
        isEmpty,
        reason:
            'network recovery may read unrelated task status; consent must not query voices',
      );
    },
  );
  for (final signedOut in [false, true]) {
    testWidgets(
      'closed or stale owner ignores late precheck: signedOut=$signedOut',
      (tester) async {
        final fixture = ApologyProviderFixture(entry);
        addTearDown(fixture.dispose);
        await fixture.open(tester);
        final controller = fixture.container.read(
          conversationControllerProvider(entry).notifier,
        );
        if (signedOut) {
          await fixture.container
              .read(sessionControllerProvider.notifier)
              .signOut();
        } else {
          controller.close();
        }
        await fixture.complete(tester);
        expect(controller.apology!.voice.prompt, isNull);
        expect(fixture.players, isEmpty);
        expect(fixture.gateway.commands, isEmpty);
      },
    );
  }
}
