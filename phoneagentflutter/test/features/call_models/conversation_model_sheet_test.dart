import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/call_model_quality_providers.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/app/conversation_voice_providers.dart';
import 'package:phone_agent/features/attachments/data/preview_ocr_session.dart';
import 'package:phone_agent/features/call_models/domain/call_models.dart';
import 'package:phone_agent/features/call_models/domain/call_model_quality.dart';
import 'package:phone_agent/features/call_models/presentation/controller/call_model_controller.dart';
import 'package:phone_agent/features/call_models/presentation/pages/call_models_page.dart';
import 'package:phone_agent/features/call_models/presentation/pages/call_model_sheet.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_route.dart';
import '../attachments/ocr_conversation_flow_test.dart' show createConversation;
import '../../support/pump_ui_transitions.dart';
import '../../../tool/previews/shell_task_parity_ports.dart';

class _Quality implements CallModelQualityRepository {
  final pending = <Completer<Map<String, CallModelReading>>>[];
  @override
  Future<Map<String, CallModelReading>> refresh() {
    final next = Completer<Map<String, CallModelReading>>();
    pending.add(next);
    return next.future;
  }
}

class _ReadyQuality implements CallModelQualityRepository {
  @override
  Future<Map<String, CallModelReading>> refresh() async => {};
}

class _Models implements CallModelRepository {
  var selections = 0;
  int failedReadsRemaining = 0;
  @override
  Future<CallModelCatalog> load() async {
    if (failedReadsRemaining > 0) {
      failedReadsRemaining--;
      throw StateError('synthetic connection loss');
    }
    return const CallModelCatalog('QWEN_OMNI_PLUS', [
      CallModel(
        id: 'QWEN_OMNI_PLUS',
        name: 'QwenOmniPlus',
        description: '模型说明',
        available: true,
        active: true,
        multiplier: 1,
      ),
      CallModel(
        id: 'DOUBAO',
        name: 'Seeduplex',
        description: '模型说明',
        available: true,
        active: false,
        multiplier: 1.1,
      ),
      CallModel(
        id: 'DOUBAO_SEEDUPLEX_3_0',
        name: 'Seeduplex V3',
        description: '模型说明',
        available: true,
        active: false,
        multiplier: 1.5,
      ),
    ]);
  }

  @override
  Future<CallModelCatalog> select(String provider) {
    selections++;
    return load();
  }

  @override
  Future<CallVoiceCatalog> loadVoices(String provider) async =>
      const CallVoiceCatalog('', '', []);
  @override
  Future<CallVoiceCatalog> selectVoice(String provider, String voice) =>
      loadVoices(provider);
}

void main() {
  testWidgets(
    'closing model sheet is distinct from explicitly selecting the current account model',
    (tester) async {
      final models = _Models();
      final returned = <CallModel?>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            callModelControllerProvider.overrideWith(
              (ref) => CallModelController(models)..load(),
            ),
            callModelQualityRepositoryProvider.overrideWithValue(
              _ReadyQuality(),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async =>
                      returned.add(await CallModelSheet.open(context)),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpUntilUiSettled();
      tester.widget<CallModelsPage>(find.byType(CallModelsPage)).onBack();
      await tester.pumpUntilUiSettled();
      expect(returned, [null]);
      await tester.tap(find.text('open'));
      await tester.pumpUntilUiSettled();
      final page = tester.widget<CallModelsPage>(find.byType(CallModelsPage));
      page.onSelect((await models.load()).current!);
      await tester.pumpUntilUiSettled();
      expect(returned.last?.id, 'QWEN_OMNI_PLUS');
      expect(
        models.selections,
        0,
        reason: 'explicit selection of same model does not rewrite preferences',
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform failed catalog retry and account change isolate modal',
      (tester) async {
        final quality = _Quality();
        final models = _Models()..failedReadsRemaining = 2;
        final epoch = StateProvider<int?>((ref) => null);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              loginEpochProvider.overrideWith((ref) => ref.watch(epoch)),
              callModelControllerProvider.overrideWith(
                (ref) => CallModelController(models)..load(),
              ),
              callModelQualityRepositoryProvider.overrideWithValue(quality),
            ],
            child: MaterialApp(
              theme: ThemeData(platform: platform),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => CallModelSheet.open(context),
                    child: const Text('open sheet'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open sheet'));
        await tester.pumpUntilUiSettled();
        expect(find.text('模型加载失败，请重试'), findsOneWidget);
        expect(quality.pending, isEmpty);
        await tester.tap(find.text('重试'));
        await tester.pump();
        await tester.pump();
        expect(quality.pending, hasLength(1));
        final container = ProviderScope.containerOf(
          tester.element(find.byType(CallModelSheet)),
        );
        container.read(epoch.notifier).state = 2;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpUntilUiSettled();
        expect(find.byType(CallModelsPage), findsNothing);
        quality.pending.single.complete({
          'QWEN_OMNI_PLUS': CallModelReading.probe(
            available: true,
            latencyMs: 1,
          ),
        });
        await tester.pumpUntilUiSettled();
        expect(find.text('1ms'), findsNothing);
        expect(models.selections, 0);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpUntilUiSettled();
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      '$platform task sheet auto refresh, content height, stale close and multiplier',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final semantics = tester.ensureSemantics();
        final models = _Models();
        final quality = _Quality();
        final ports = PreviewOcrSession();
        final conversation = createConversation(ports);
        const entry = ConversationEntry(sessionId: PreviewOcrSession.sessionId);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...shellTaskParityOverrides(),
              currentAccountIdProvider.overrideWithValue('synthetic-model'),
              voiceInputAvailableProvider.overrideWithValue(false),
              voiceInputFactoryProvider.overrideWithValue(
                (_) => throw StateError('No audio in sheet test'),
              ),
              conversationControllerProvider(
                entry,
              ).overrideWith((ref) => conversation),
              callModelControllerProvider.overrideWith(
                (ref) => CallModelController(models)..load(),
              ),
              callModelQualityRepositoryProvider.overrideWithValue(quality),
            ],
            child: MaterialApp(
              theme: ThemeData(platform: platform),
              home: const ConversationRoute(entry: entry),
            ),
          ),
        );
        await tester.pumpUntilUiSettled();
        expect(find.text('QwenOmniPlus ×1.0'), findsOneWidget);
        expect(find.byType(CallModelSheet), findsNothing);
        expect(quality.pending, isEmpty);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(ConversationRoute)),
        );
        await container.read(callModelControllerProvider.notifier).load();
        await tester.pumpUntilUiSettled();
        await tester.pump(const Duration(seconds: 5));
        expect(
          find.byType(CallModelSheet),
          findsNothing,
          reason: 'catalog refresh and page state must not open a sheet',
        );
        expect(quality.pending, isEmpty);
        await tester.tap(find.byKey(const ValueKey('conversation-model')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        expect(quality.pending, hasLength(1));
        final rect = tester.getRect(find.byType(CallModelsPage));
        expect(
          rect.height,
          lessThan(450),
          reason: 'v66 sheet wraps its three rows',
        );
        expect(rect.bottom, 844);
        quality.pending.single.complete({
          'QWEN_OMNI_PLUS': CallModelReading.probe(
            available: true,
            latencyMs: 199,
          ),
        });
        await tester.pumpUntilUiSettled();
        expect(find.text('199ms'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('刷新模型状态'));
        await tester.pump();
        expect(quality.pending, hasLength(2));
        await tester.tap(find.bySemanticsLabel('正在刷新模型状态'));
        expect(quality.pending, hasLength(2));
        await tester.tap(find.bySemanticsLabel('关闭'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await container.read(callModelControllerProvider.notifier).load();
        await tester.pumpUntilUiSettled();
        expect(
          find.byType(CallModelSheet),
          findsNothing,
          reason: 'closed sheet must stay closed after catalog refresh',
        );
        await tester.tap(find.byKey(const ValueKey('conversation-model')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        expect(quality.pending, hasLength(3));
        quality.pending[1].complete({
          'QWEN_OMNI_PLUS': CallModelReading.probe(
            available: true,
            latencyMs: 1,
          ),
        });
        await tester.pump();
        expect(find.text('1ms'), findsNothing);
        quality.pending.last.complete({
          'QWEN_OMNI_PLUS': CallModelReading.probe(
            available: true,
            latencyMs: 222,
          ),
        });
        await tester.pumpUntilUiSettled();
        expect(find.text('222ms'), findsOneWidget);
        expect(models.selections, 0);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpUntilUiSettled();
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }
}
