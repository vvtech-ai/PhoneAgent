import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/apology_voice_providers.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/features/apology/domain/apology_voice.dart';
import 'package:phone_agent/features/apology/presentation/controller/apology_conversation_binding.dart';
import 'package:phone_agent/features/call_models/domain/call_models.dart';
import 'package:phone_agent/features/call_models/presentation/controller/call_model_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import '../../../tool/previews/shell_conversation_fakes.dart';

class _Models implements CallModelRepository {
  String active = '1';
  int writes = 0;
  final unavailable = <String>{};
  @override
  Future<CallModelCatalog> load() async => CallModelCatalog(active, [
    for (final id in ['1', '2'])
      CallModel(
        id: id,
        name: '模型$id',
        description: '',
        available: !unavailable.contains(id),
        active: active == id,
      ),
  ]);
  @override
  Future<CallModelCatalog> select(String id) async {
    writes++;
    active = id;
    return load();
  }

  @override
  Future<CallVoiceCatalog> loadVoices(String id) async =>
      const CallVoiceCatalog('', '', []);
  @override
  Future<CallVoiceCatalog> selectVoice(String p, String v) => loadVoices(p);
}

class _Voices implements ApologyVoicePort {
  _Voices([this.available = const [ApologyVoice('2', '模型2', 'synthetic-b')]]);
  final List<ApologyVoice> available;
  @override
  Future<List<ApologyVoice>> voices() async => available;
  @override
  Future<void> confirmCandidate(ApologyVoice voice) async {}
}

Future<void> flush() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test(
    'restoring after the fresh directory arrived still checks task permission',
    () async {
      final models = _Models()..unavailable.add('2');
      final modelController = CallModelController(models);
      await modelController.load();
      late ConversationController controller;
      final binding = Provider<void>(
        (ref) => bindApologyModelChanges(ref, controller),
      );
      final container = ProviderContainer(
        overrides: [
          callModelControllerProvider.overrideWith((ref) => modelController),
        ],
      );
      addTearDown(container.dispose);
      controller = ConversationController(
        entry: const ConversationEntry(
          sessionId: 'task',
          skillId: 'apology_master',
        ),
        accountId: 'synthetic',
        gateway: OfflineAgent(),
        history: OfflineHistory(),
        apologyVoice: ApologyVoiceDependencies(
          port: _Voices(const [
            ApologyVoice('1', '模型1', 'synthetic-a', active: true),
          ]),
          model: () => '1',
          modelName: () => '模型1',
        ),
      );
      addTearDown(controller.dispose);
      controller.apology!.voice.restore('2');
      container.read(binding);
      await flush();
      expect(controller.apology!.voice.modelId, '1');
      expect(controller.apology!.voice.selection?.assetId, 'synthetic-a');
      expect(models.writes, 0);
    },
  );

  test(
    'missing task voice names the task model instead of the global default',
    () async {
      final models = _Models();
      final modelController = CallModelController(models);
      await modelController.load();
      final dependencies = Provider((ref) => apologyVoiceDependencies(ref));
      final container = ProviderContainer(
        overrides: [
          callModelControllerProvider.overrideWith((ref) => modelController),
          apologyVoicePortProvider.overrideWithValue(_Voices(const [])),
        ],
      );
      addTearDown(container.dispose);
      final keep = container.listen(callModelControllerProvider, (_, __) {});
      addTearDown(keep.close);
      final controller = ConversationController(
        entry: const ConversationEntry(
          sessionId: 'task',
          skillId: 'apology_master',
        ),
        accountId: 'synthetic',
        gateway: OfflineAgent(),
        history: OfflineHistory(),
        apologyVoice: container.read(dependencies),
      );
      addTearDown(controller.dispose);
      controller.apology!.voice.restore('1');
      controller.apology!.voice.modelChanged('2');
      await flush();
      expect(
        controller.apology!.voice.prompt?.text,
        startsWith('模型2没有您的可用克隆音色'),
      );
      expect(models.active, '1');
      expect(models.writes, 0);
    },
  );

  test(
    'revoked task model follows available default and no models blocks until refreshed',
    () async {
      final models = _Models();
      final modelController = CallModelController(models);
      await modelController.load();
      late ConversationController controller;
      final binding = Provider<void>(
        (ref) => bindApologyModelChanges(ref, controller),
      );
      final container = ProviderContainer(
        overrides: [
          callModelControllerProvider.overrideWith((ref) => modelController),
        ],
      );
      addTearDown(container.dispose);
      final gateway = OfflineAgent();
      controller = ConversationController(
        entry: const ConversationEntry(
          sessionId: 'task',
          skillId: 'apology_master',
        ),
        accountId: 'synthetic',
        gateway: gateway,
        history: OfflineHistory(),
        apologyVoice: ApologyVoiceDependencies(
          port: _Voices(const [
            ApologyVoice('1', '模型1', 'synthetic-a', active: true),
            ApologyVoice('2', '模型2', 'synthetic-b', active: true),
          ]),
          model: () => '1',
          modelName: () => '模型1',
        ),
      );
      addTearDown(controller.dispose);
      controller.apology!.voice.restore('2');
      container.read(binding);
      models.unavailable.addAll(['1', '2']);
      await modelController.load();
      await flush();
      expect(controller.apology!.voice.blocked, isTrue);
      expect(controller.apology!.voice.prompt?.text, contains('暂无可用通话模型'));
      controller.send('帮我向伴侣道歉');
      expect(gateway.commands, isEmpty);
      models.active = '2';
      models.unavailable.remove('2');
      await modelController.load();
      await flush();
      expect(controller.apology!.voice.modelId, '2');
      expect(controller.apology!.voice.blocked, isFalse);
      models.active = '1';
      models.unavailable
        ..add('2')
        ..remove('1');
      await modelController.load();
      await flush();
      expect(controller.apology!.voice.modelId, '1');
      expect(controller.apology!.voice.blocked, isFalse);
      expect(
        models.writes,
        0,
        reason: 'directory fallback does not trigger a second global PUT',
      );
    },
  );

  test(
    'a fresh global default never replaces a still allowed task model',
    () async {
      final models = _Models();
      final modelController = CallModelController(models);
      await modelController.load();
      late ConversationController controller;
      final binding = Provider<void>((ref) {
        bindApologyModelChanges(ref, controller);
      });
      final container = ProviderContainer(
        overrides: [
          callModelControllerProvider.overrideWith((ref) => modelController),
        ],
      );
      addTearDown(container.dispose);
      controller = ConversationController(
        entry: const ConversationEntry(
          sessionId: 'task',
          skillId: 'apology_master',
        ),
        accountId: 'synthetic',
        gateway: OfflineAgent(),
        history: OfflineHistory(),
      );
      addTearDown(controller.dispose);
      controller.apology!.voice.restore('2');
      container.read(binding);
      await modelController.select(modelController.state.catalog!.models[1]);
      await modelController.select(modelController.state.catalog!.models[0]);
      await flush();
      expect(controller.apology!.voice.modelId, '2');
      expect(controller.apology!.voice.blocked, isFalse);
      expect(models.writes, 2);
    },
  );

  test(
    'choosing an apology voice changes this task only, not account model preference',
    () async {
      final models = _Models();
      final modelController = CallModelController(models);
      await modelController.load();
      final dependencies = Provider((ref) => apologyVoiceDependencies(ref));
      final container = ProviderContainer(
        overrides: [
          callModelControllerProvider.overrideWith((ref) => modelController),
          apologyVoicePortProvider.overrideWithValue(_Voices()),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        callModelControllerProvider,
        (_, __) {},
      );
      addTearDown(subscription.close);
      final gateway = OfflineAgent();
      final controller = ConversationController(
        entry: const ConversationEntry(
          sessionId: 's',
          skillId: 'apology_master',
        ),
        accountId: 'synthetic',
        gateway: gateway,
        history: OfflineHistory(),
        apologyVoice: container.read(dependencies),
      );
      addTearDown(controller.dispose);
      controller.send('确认使用');
      await flush();
      controller.apology!.voice.choose('model:2');
      await flush();
      controller.send('确认使用');
      await flush();
      controller.send('帮我向伴侣道歉');
      expect(gateway.commands.single.callVoiceSelection?['modelId'], '2');
      expect(models.active, '1');
      expect(models.writes, 0);
      expect(modelController.state.catalog?.activeProvider, '1');
    },
  );
}
