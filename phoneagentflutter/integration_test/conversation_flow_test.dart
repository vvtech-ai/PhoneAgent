import '../test/support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/app/translation_history_providers.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import '../test/support/shell_fakes.dart';
import '../test/support/conversation_fakes.dart';
import '../test/support/translation_history_fake.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('tasks restore closed session and unified multi-turn text', (
    tester,
  ) async {
    final gateway = OfflineAgent();
    final translations = OfflineTranslationHistory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStoreProvider.overrideWithValue(OfflineSessionStore()),
          homeRepositoryProvider.overrideWithValue(FakeHomeRepository()),
          callModelRepositoryProvider.overrideWithValue(
            FakeCallModelRepository(),
          ),
          taskRepositoryProvider.overrideWithValue(OfflineTasks()),
          historyRepositoryProvider.overrideWithValue(OfflineHistory()),
          agentGatewayProvider.overrideWithValue(gateway),
          translationHistoryRepositoryProvider.overrideWithValue(translations),
        ],
        child: const PhoneAgentApp(),
      ),
    );
    await tester.pumpUntilUiSettled();
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpUntilUiSettled();
    Future<void> tap(String key) async {
      final finder = find.byKey(ValueKey(key));
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpUntilUiSettled();
      expect(tester.takeException(), isNull);
    }

    await tap('tab-2');
    expect(find.text('订餐厅 · 合成历史'), findsOneWidget);
    await binding.takeScreenshot('tasks');
    await tap('conversation:closed');
    expect(find.text('历史任务已保存，可继续对话。'), findsOneWidget);
    expect(find.byKey(const ValueKey('toggle-text')), findsOneWidget);
    await binding.takeScreenshot('restored-voice');
    await tap('toggle-text');
    await tester.enterText(
      find.byKey(const ValueKey('conversation-input')),
      '再推荐两家餐厅',
    );
    await tester.pumpUntilUiSettled();
    await tap('send-text');
    await tester.pumpUntilUiSettled(const Duration(milliseconds: 200));
    expect(find.text('请选择餐厅'), findsOneWidget);
    await binding.takeScreenshot('options');
    await tester.tap(find.text('2. 合成餐厅乙\n适合聚餐'));
    await tester.pumpUntilUiSettled(const Duration(milliseconds: 200));
    expect(gateway.commands.last.message, '第 2 个');
    expect(
      gateway.commands.every((c) => c.toJson()['channel'] == 'voice'),
      isTrue,
    );
    expect(find.text('已收到你的选择。'), findsOneWidget);
    await binding.takeScreenshot('text-result');
    await tap('close-conversation');
    expect(find.text('任务'), findsWidgets);
    await tap('conversation:closed');
    await tester.binding.handlePopRoute();
    await tester.pumpUntilUiSettled();
    expect(find.byKey(const ValueKey('toggle-text')), findsNothing);
    translations.fail = true;
    await tap('call:translation');
    expect(find.byKey(const ValueKey('retry-translation')), findsOneWidget);
    translations.fail = false;
    await tap('retry-translation');
    expect(find.text('你好，在吗？'), findsOneWidget);
    expect(find.text('Hello?'), findsOneWidget);
    await binding.takeScreenshot('translation-history');
    await tap('close-translation');
    await tap('call:ordinary');
    await tap('task-detail-restore');
    expect(find.byKey(const ValueKey('toggle-text')), findsOneWidget);
    expect(find.text('历史任务已保存，可继续对话。'), findsNothing);
    await tap('close-conversation');
    binding.reportData = {
      ...?binding.reportData,
      'routes': [
        'tasks',
        'unified-voice',
        'unified-text',
        'translation-history',
      ],
      'cases': [
        'closed-restore',
        'toggle',
        'send',
        'ordinal',
        'stream',
        'explicit-close',
        'system-back',
        'translation-retry',
        'non-final-subtitle',
        'translation-close',
        'ordinary-new-unified',
      ],
      'commands': gateway.commands.length,
      'network': 'none; synthetic repositories only',
    };
  });
}
