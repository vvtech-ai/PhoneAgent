import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/call_model_quality_providers.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/app/conversation_voice_providers.dart';
import 'package:phone_agent/features/apology/domain/apology_voice.dart';
import 'package:phone_agent/features/apology/presentation/controller/apology_conversation_binding.dart';
import 'package:phone_agent/features/call_models/domain/call_model_quality.dart';
import 'package:phone_agent/features/call_models/domain/call_models.dart';
import 'package:phone_agent/features/call_models/presentation/controller/call_model_controller.dart';
import 'package:phone_agent/features/call_models/presentation/pages/call_models_page.dart';
import 'package:phone_agent/features/call_models/presentation/widgets/native_model_card.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_route.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import '../../../tool/previews/shell_conversation_fakes.dart';
import '../../../tool/previews/shell_task_parity_ports.dart';
import '../../support/pump_ui_transitions.dart';

class _Models implements CallModelRepository {
  String active = '1';
  int reads = 0, writes = 0;
  final denied = <String>{};
  @override
  Future<CallModelCatalog> load() async {
    reads++;
    return CallModelCatalog(active, [
      for (final id in ['1', '2', '3'])
        CallModel(
          id: id,
          name: '模型$id',
          description: '',
          available: !denied.contains(id),
          active: active == id,
          multiplier: double.parse(id),
        ),
    ]);
  }

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

class _Quality implements CallModelQualityRepository {
  @override
  Future<Map<String, CallModelReading>> refresh() async => {};
}

class _Voices implements ApologyVoicePort {
  @override
  Future<List<ApologyVoice>> voices() async => const [
    ApologyVoice('2', '模型2', 'synthetic-2', active: true),
    ApologyVoice('3', '模型3', 'synthetic-3', active: true),
  ];
  @override
  Future<void> confirmCandidate(ApologyVoice voice) async {}
}

class _History extends OfflineHistory {
  @override
  Future<RestoredConversation> restore(String sessionId) async {
    final value = await super.restore(sessionId);
    return RestoredConversation(
      ConversationDetail(
        sessionId: sessionId,
        title: '合成历史任务',
        status: 'ACTIVE',
        pinnedSkillId: 'apology_master',
        taskCallModelId: '2',
      ),
      ledger: value.ledger,
    );
  }
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform restored task model owns label and modal selection; manual choice saves both',
      (tester) async {
        const entry = ConversationEntry(sessionId: 'task', restore: true);
        final models = _Models();
        final modelController = CallModelController(models);
        await modelController.load();
        final conversation = ConversationController(
          entry: entry,
          accountId: 'synthetic',
          gateway: OfflineAgent(),
          history: _History(),
          apologyVoice: ApologyVoiceDependencies(
            port: _Voices(),
            model: () => '1',
            modelName: () => '模型1',
          ),
        );
        await conversation.restore();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...shellTaskParityOverrides(),
              currentAccountIdProvider.overrideWithValue('synthetic'),
              voiceInputAvailableProvider.overrideWithValue(false),
              voiceInputFactoryProvider.overrideWithValue(
                (_) => throw StateError('No audio'),
              ),
              conversationControllerProvider(
                entry,
              ).overrideWith((ref) => conversation),
              callModelControllerProvider.overrideWith(
                (ref) => modelController,
              ),
              callModelQualityRepositoryProvider.overrideWithValue(_Quality()),
            ],
            child: MaterialApp(
              theme: ThemeData(platform: platform),
              home: const ConversationRoute(entry: entry),
            ),
          ),
        );
        await tester.pumpUntilUiSettled();
        expect(find.text('模型2 ×2.0'), findsOneWidget);
        final reads = models.reads;
        await tester.tap(find.byKey(const ValueKey('conversation-model')));
        await tester.pumpUntilUiSettled();
        final cards = tester.widgetList<NativeModelCard>(
          find.byType(NativeModelCard),
        );
        expect(cards.singleWhere((c) => c.selected).model.id, '2');
        expect(
          models.reads,
          greaterThan(reads),
          reason: 'opening a model modal refreshes permissions',
        );
        models.denied.add('2');
        await modelController.load();
        await tester.pumpUntilUiSettled();
        expect(
          tester
              .widgetList<NativeModelCard>(find.byType(NativeModelCard))
              .singleWhere((c) => c.selected)
              .model
              .id,
          '1',
        );
        models.denied.clear();
        await modelController.load();
        await tester.pumpUntilUiSettled();
        tester.widget<CallModelsPage>(find.byType(CallModelsPage)).onBack();
        await tester.pumpUntilUiSettled();
        expect(conversation.apology!.voice.modelId, '2');
        expect(models.active, '1');
        expect(models.writes, 0);
        await tester.tap(find.byKey(const ValueKey('conversation-model')));
        await tester.pumpUntilUiSettled();
        await tester.tap(find.byKey(const ValueKey('model-3')));
        await tester.pumpUntilUiSettled();
        expect(models.writes, 1);
        expect(models.active, '3');
        expect(conversation.apology!.voice.modelId, '3');
        expect(conversation.apology!.voice.blocked, isFalse);
        expect(find.text('模型3 ×3.0'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpUntilUiSettled();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
