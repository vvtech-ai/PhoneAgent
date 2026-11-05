import 'support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';
import 'package:phone_agent/features/settings/presentation/widgets/native_original_audio_controls.dart';
import '../tool/previews/auth_scenario.dart';
import '../tool/previews/migration_workbench.dart';
import '../tool/previews/workbench_catalog.dart';
import 'support/conversation_fakes.dart';
import 'support/shell_fakes.dart';

void main() {
  for (final width in [320.0, 430.0]) {
    testWidgets('shared shell continuous flow and reset at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final scene = workbenchScenes.singleWhere((s) => s.id == 'app');
      await tester.pumpWidget(MigrationWorkbench(scenes: [scene]));
      Future<void> tap(Finder target) async {
        await tester.pumpUntilUiSettled();
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpUntilUiSettled();
        expect(tester.takeException(), isNull);
      }

      Future<void> tapKey(String id) => tap(find.byKey(ValueKey(id)));
      Future<void> back() async {
        await tap(
          find.byType(BackButton).evaluate().isNotEmpty
              ? find.byType(BackButton)
              : find.byTooltip('返回'),
        );
      }

      await tapKey('scene-app');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PhoneAgentApp)),
      );
      final auth = container.read(sessionStoreProvider) as AuthScenario;
      final models =
          container.read(callModelRepositoryProvider)
              as FakeCallModelRepository;
      final agent = container.read(agentGatewayProvider) as OfflineAgent;
      expect(container.read(appConfigProvider).apiBaseUri, isNull);
      expect(auth.sends, 0);

      await tapKey('homeVoiceModelChip');
      await tapKey('model-DOUBAO');
      expect(models.provider, 'DOUBAO');
      await tester.drag(
        find.byKey(const PageStorageKey('home-scroll')),
        const Offset(0, 700),
      );
      await tester.pumpUntilUiSettled();
      await tapKey('open-points-wallet');
      expect(find.text('会员与积分'), findsOneWidget);
      await tap(find.text('查看积分流水'));
      expect(find.byKey(const ValueKey('points-ledger-1')), findsOneWidget);
      await back();
      await back();

      await tapKey('skill-restaurant_booking');
      await tapKey('toggle-text');
      await tester.enterText(
        find.byKey(const ValueKey('conversation-input')),
        '帮我订餐厅',
      );
      await tapKey('send-text');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpUntilUiSettled();
      expect(find.textContaining('合成餐厅甲'), findsOneWidget);
      final created = agent.commands.single.sessionId;
      await tapKey('close-conversation');
      await tapKey('tab-2');
      await tapKey('conversation:$created');
      expect(find.text('帮我订餐厅'), findsOneWidget, reason: '直接显示原会话中的历史用户消息');
      expect(find.textContaining('合成餐厅甲'), findsOneWidget);
      expect(agent.commands.length, 1, reason: '恢复不提交新命令');
      await tap(find.textContaining('合成餐厅甲'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpUntilUiSettled();
      expect(find.text('已收到你的选择。'), findsOneWidget);
      expect(agent.commands.length, 2);
      await tapKey('close-conversation');
      await tapKey('conversation:$created');
      expect(find.text('已收到你的选择。'), findsOneWidget);
      await tap(find.textContaining('合成餐厅甲'));
      expect(agent.commands.length, 2, reason: '已处理候选不可重发');
      await tapKey('toggle-text');
      await tester.enterText(
        find.byKey(const ValueKey('conversation-input')),
        '请安排靠窗座位',
      );
      await tapKey('send-text');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpUntilUiSettled();
      expect(find.text('已收到补充要求，当前为 MOCK，未拨号。'), findsOneWidget);
      expect(agent.commands.length, 3);
      await tapKey('close-conversation');
      await tapKey('tab-2');
      await tapKey('conversation:closed');
      expect(find.text('历史任务已保存，可继续对话。'), findsOneWidget);
      await tapKey('close-conversation');

      await tapKey('tab-3');
      await tapKey('settings-originalAudio');
      await tap(find.byType(NativeAudioToggle));
      expect(
        tester.widget<NativeAudioToggle>(find.byType(NativeAudioToggle)).value,
        isTrue,
      );
      await back();
      await tapKey('settings-originalAudio');
      expect(
        tester.widget<NativeAudioToggle>(find.byType(NativeAudioToggle)).value,
        isTrue,
      );
      await back();
      await tapKey('settings-logout');
      await tap(find.byKey(const ValueKey('logout-confirm')));
      expect(auth.saved, isNull);
      await tester.enterText(
        find.byKey(const ValueKey('loginPhone')),
        '13800000000',
      );
      await tester.enterText(find.byKey(const ValueKey('loginCode')), '123456');
      await tapKey('loginAgreement');
      await tapKey('loginBtn');
      expect(find.byKey(const ValueKey('homeVoiceModelChip')), findsOneWidget);
      expect(auth.sends, 0);
      expect(auth.submissions.length, 1);
      expect(
        (await container
                .read(taskRepositoryProvider)
                .load(TaskSource.conversations))
            .any((row) => row.sessionId == created),
        isFalse,
        reason: '退出合成登录后新会话数据重置',
      );

      await tapKey('workbench-home');
      await tapKey('scene-app');
      final fresh = ProviderScope.containerOf(
        tester.element(find.byType(PhoneAgentApp)),
      );
      expect(identical(fresh, container), isFalse);
      expect(
        (fresh.read(callModelRepositoryProvider) as FakeCallModelRepository)
            .provider,
        'QWEN_OMNI_PLUS',
      );
      await tapKey('workbench-home');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpUntilUiSettled();
      expect(tester.takeException(), isNull);
    });
  }
}
