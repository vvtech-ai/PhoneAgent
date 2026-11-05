import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/call_models/domain/call_models.dart';
import 'package:phone_agent/features/call_models/domain/clone_voice.dart';
import 'package:phone_agent/features/call_models/presentation/controller/call_model_controller.dart';
import 'package:phone_agent/features/call_models/presentation/pages/call_voices_page.dart';

const ready = CloneVoiceSnapshot(
  modelId: 'QWEN_OMNI_PLUS',
  available: true,
  currentStatus: 'READY',
  currentHasAsset: true,
);
const voices = CallVoiceCatalog('a', 'AI', [CallVoice('a', '系统音色甲', '', true)]);

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('select clone/AI and return at $width', (tester) async {
      tester.view.physicalSize = Size(width, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var cloneClicks = 0, aiClicks = 0, backs = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CallVoicesPage(
              state: const CallModelState(
                voiceProvider: 'QWEN_OMNI_PLUS',
                clone: ready,
                voices: voices,
              ),
              onBack: () => backs++,
              onRetry: () {},
              onSelect: (_) => aiClicks++,
              onSelectClone: () => cloneClicks++,
            ),
          ),
        ),
      );
      await tester.tap(find.text('使用我的克隆音色'));
      expect(cloneClicks, 1);
      await tester.ensureVisible(find.text('系统音色甲'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('系统音色甲'));
      expect(aiClicks, 0); // Already selected: native row does not resubmit.
      await tester.tap(find.byTooltip('关闭音色选择'));
      expect(backs, 1);
      expect(tester.takeException(), isNull);
    });
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform clone empty action works at short 2x size', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var creates = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: CallVoicesPage(
              state: const CallModelState(
                voiceProvider: 'QWEN_OMNI_PLUS',
                voices: voices,
              ),
              onBack: () {},
              onRetry: () {},
              onSelect: (_) {},
              onSelectClone: () {},
              onCreateClone: () => creates++,
            ),
          ),
        ),
      );
      expect(find.text('声音克隆'), findsOneWidget);
      expect(find.text('创建我的声音克隆'), findsNothing);
      expect(find.text('—'), findsOneWidget);
      expect(find.text('300'), findsNothing);
      await tester.ensureVisible(find.text('声音克隆'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('声音克隆'));
      await tester.pump();
      expect(creates, 1);
      expect(tester.takeException(), isNull);
    });
  }

  final scenarios = <String, CallModelState>{
    '尚未克隆': const CallModelState(
      voiceProvider: 'QWEN_OMNI_PLUS',
      voices: voices,
      clone: CloneVoiceSnapshot(
        modelId: 'QWEN_OMNI_PLUS',
        available: true,
        currentStatus: 'NOT_CREATED',
        currentHasAsset: false,
      ),
    ),
    '克隆处理中': const CallModelState(
      voiceProvider: 'QWEN_OMNI_PLUS',
      voices: voices,
      clone: CloneVoiceSnapshot(
        modelId: 'QWEN_OMNI_PLUS',
        available: true,
        currentStatus: 'PROCESSING',
        currentHasAsset: false,
      ),
    ),
    '读取失败': const CallModelState(
      voiceProvider: 'QWEN_OMNI_PLUS',
      voices: voices,
      cloneError: '克隆音色读取失败，请重试',
    ),
    '等待同步': const CallModelState(
      voiceProvider: 'QWEN_OMNI_PLUS',
      voices: voices,
      clone: ready,
      cloneNeedsRefresh: true,
    ),
    '当前使用': const CallModelState(
      voiceProvider: 'QWEN_OMNI_PLUS',
      clone: ready,
      voices: CallVoiceCatalog('', 'CLONE', []),
    ),
    '新音色待确认': const CallModelState(
      voiceProvider: 'QWEN_OMNI_PLUS',
      voices: voices,
      clone: CloneVoiceSnapshot(
        modelId: 'QWEN_OMNI_PLUS',
        available: true,
        currentStatus: 'NOT_CREATED',
        currentHasAsset: false,
        candidateStatus: 'READY',
        candidateBillingStatus: 'CHARGED',
      ),
    ),
  };
  for (final scenario in scenarios.entries) {
    testWidgets('clone state ${scenario.key} and correct action gate', (
      tester,
    ) async {
      var selects = 0, refreshes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CallVoicesPage(
              state: scenario.value,
              onBack: () {},
              onRetry: () => refreshes++,
              onSelect: (_) => selects++,
              onSelectClone: () => selects++,
            ),
          ),
        ),
      );
      if (const {'等待同步', '读取失败', '克隆处理中'}.contains(scenario.key)) {
        expect(find.text(scenario.key), findsOneWidget);
      } else {
        expect(find.text(scenario.key), findsNothing);
      }
      final action = find.byKey(const ValueKey('selectCloneVoice'));
      if (scenario.key == '新音色待确认') {
        await tester.tap(action);
        expect(selects, 1);
      } else if (action.evaluate().isNotEmpty) {
        expect(
          tester
              .widget<InkWell>(
                find.descendant(
                  of: action,
                  matching: find.byKey(
                    const ValueKey('voice-selection:__CLONE__'),
                  ),
                ),
              )
              .onTap,
          isNull,
        );
      }
      final refresh = find.text(scenario.key == '等待同步' ? '同步状态' : '刷新克隆状态');
      if (const {'等待同步', '读取失败', '克隆处理中'}.contains(scenario.key)) {
        await tester.tap(refresh);
        expect(refreshes, 1);
      } else {
        expect(refresh, findsNothing);
        expect(refreshes, 0);
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('unsupported model has no clone card', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CallVoicesPage(
            state: const CallModelState(
              voiceProvider: 'DOUBAO',
              voices: voices,
            ),
            onBack: () {},
            onRetry: () {},
            onSelect: (_) {},
            onSelectClone: () {},
          ),
        ),
      ),
    );
    expect(find.text('我的克隆音色'), findsNothing);
    expect(find.text('系统音色甲'), findsOneWidget);
  });
  testWidgets('saving disables clone, AI and refresh together', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CallVoicesPage(
            state: const CallModelState(
              voiceProvider: 'QWEN_OMNI_PLUS',
              voices: voices,
              clone: ready,
              voiceSaving: true,
            ),
            onBack: () {},
            onRetry: () => fail('busy'),
            onSelect: (_) => fail('busy'),
            onSelectClone: () => fail('busy'),
          ),
        ),
      ),
    );
    expect(
      tester
          .widgetList<InkWell>(
            find.descendant(
              of: find.byKey(const ValueKey('selectCloneVoice')),
              matching: find.byKey(const ValueKey('voice-selection:__CLONE__')),
            ),
          )
          .map((button) => button.onTap),
      everyElement(isNull),
    );
    expect(
      tester
          .widgetList<InkWell>(
            find.descendant(
              of: find.byKey(const ValueKey('voice-a')),
              matching: find.byType(InkWell),
            ),
          )
          .map((button) => button.onTap),
      everyElement(isNull),
    );
    expect(find.text('刷新克隆状态'), findsNothing);
  });
}
