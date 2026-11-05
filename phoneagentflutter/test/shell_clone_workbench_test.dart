import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/features/call_models/presentation/pages/call_voices_page.dart';
import 'support/pump_ui_transitions.dart';
import 'package:phone_agent/features/settings/presentation/pages/settings_route.dart';
import 'package:phone_agent/features/call_models/presentation/widgets/native_voice_selection_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:phone_agent/features/identity/presentation/pages/identity_route.dart';
import 'package:phone_agent/features/voice_clone/presentation/pages/clone_flow_page.dart';
import 'package:phone_agent/features/voice_clone/presentation/widgets/native_clone_controls.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/clone_flow_providers.dart';
import 'package:phone_agent/app/identity_providers.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/identity/domain/identity_profile.dart';
import '../tool/previews/auth_scenario.dart';
import '../tool/previews/migration_workbench.dart';
import '../tool/previews/shell_clone_ports.dart';
import '../tool/previews/workbench_catalog.dart';

void main() {
  test('production clone presentation does not claim a synthetic flow', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(cloneFlowPreviewProvider), isFalse);
  });
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('identity clone keeps source route on $platform', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final scene = workbenchScenes.singleWhere((value) => value.id == 'app');
      await tester.pumpWidget(MigrationWorkbench(scenes: [scene]));
      Future<void> tap(Finder target) async {
        await tester.pumpUntilUiSettled();
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpUntilUiSettled();
        expect(tester.takeException(), isNull);
      }

      Future<void> key(String id) async {
        if (id == 'settings-identity') {
          // Preserve identity/clone component regression; the settings entry was removed.
          tester.widget<SettingsRoute>(find.byType(SettingsRoute)).onIdentity();
          await tester.pumpUntilUiSettled();
          return;
        }
        await tap(find.byKey(ValueKey(id)));
        if (id == 'settings-models') {}
      }

      await key('scene-app');
      await key('tab-3');
      await key('settings-identity');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PhoneAgentApp)),
      );
      final identity = container.read(identityControllerProvider.notifier);
      final loading = <bool>[];
      final subscription = container.listen(
        identityControllerProvider,
        (_, state) => loading.add(state.busy || state.initialLoadStatus),
      );
      addTearDown(subscription.close);
      await tap(find.text('声音克隆'));
      expect(find.text('选择声音克隆模型'), findsOneWidget);
      expect(find.byType(IdentityRoute, skipOffstage: false), findsOneWidget);
      expect(find.text('我的身份'), findsOneWidget);
      await tap(find.byTooltip('关闭'));
      expect(find.text('我的身份'), findsOneWidget);
      expect(find.byKey(const ValueKey('settings-identity')), findsNothing);
      expect(loading, isNot(contains(true)));
      expect(
        container.read(identityControllerProvider.notifier),
        same(identity),
      );
      await tap(find.text('声音克隆'));
      await key('clone-create-QWEN_OMNI_PLUS');
      expect(find.byType(CloneCheckRow), findsOneWidget);
      await tap(
        find.descendant(
          of: find.byType(CloneFlowPage),
          matching: find.byTooltip('返回'),
        ),
      );
      expect(find.text('我的身份'), findsOneWidget);
      await tap(find.byTooltip('返回'));
      expect(find.byKey(const ValueKey('settings-identity')), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });
  }
  for (final width in [320.0, 430.0]) {
    testWidgets('shell identity and two-model clone flow at $width', (
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

      Future<void> key(String id) async {
        if (id == 'settings-identity') {
          // Preserve identity/clone component regression; the settings entry was removed.
          tester.widget<SettingsRoute>(find.byType(SettingsRoute)).onIdentity();
          await tester.pumpUntilUiSettled();
          return;
        }
        await tap(find.byKey(ValueKey(id)));
        if (id == 'settings-models') {}
      }

      await key('scene-app');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PhoneAgentApp)),
      );
      final auth = container.read(sessionStoreProvider) as AuthScenario;
      final ports =
          container.read(cloneCreationPortProvider) as ShellClonePorts;
      await key('tab-3');
      await key('settings-identity');
      expect(find.text('合成身份'), findsOneWidget);
      await tap(find.text('声音克隆'));
      await key('clone-create-QWEN_OMNI_PLUS');
      expect(find.text('MOCK · 正式流程装配演练'), findsOneWidget);
      await tap(find.byType(CloneCheckRow));
      await tap(find.text('开始认证'));
      expect(find.text('仅填写合成数据，不要输入真实身份信息'), findsOneWidget);
      await tap(find.text('填入合成测试数据'));
      await tap(find.text('开始人脸跟读认证'));
      expect(find.text('声音克隆已完成'), findsOneWidget);
      final save = find.byType(CloneCheckRow);
      if (!tester.widget<CloneCheckRow>(save).checked) await tap(save);
      await tap(find.byKey(const Key('clone-preview')));
      expect(ports.flows.single.plays, 1);
      await tap(find.byKey(const Key('clone-preview')));
      await tap(find.text('设为默认声音'));
      expect(find.text('演练已确认，真实音色未改变'), findsOneWidget);
      await tap(find.text('完成并返回'));
      expect(ports.recording, isTrue);
      expect(ports.identity.value.status, IdentityStatus.verified);
      expect(ports.catalog.cloneAssets, {'QWEN_OMNI_PLUS'});
      expect(ports.flows.single.capture.captures, 1);
      expect(ports.flows.single.closed, isTrue);

      expect(find.text('演练用户'), findsOneWidget);
      await tap(find.text('声音克隆'));
      await key('clone-create-DOUBAO_SEEDUPLEX_3_0');
      expect(find.text('声音克隆已完成'), findsOneWidget);
      expect(ports.flows.last.candidates.fromSaved, 1);
      expect(ports.flows.last.capture.captures, 0);
      await tap(find.text('设为默认声音'));
      await tap(find.text('完成并返回'));
      expect(ports.catalog.cloneAssets, {
        'QWEN_OMNI_PLUS',
        'DOUBAO_SEEDUPLEX_3_0',
      });
      expect(ports.flows.last.closed, isTrue);
      final refreshedModel = container.read(callModelControllerProvider);
      expect(refreshedModel.voiceProvider, 'DOUBAO_SEEDUPLEX_3_0');
      expect(refreshedModel.voices!.selectionMode, 'CLONE');

      await tap(find.text('声音克隆'));
      await key('clone-create-QWEN_OMNI_PLUS');
      expect(find.text('重新认证并克隆音色？'), findsOneWidget);
      await tap(find.text('取消'));
      await tap(find.byTooltip('关闭'));
      expect(find.text('我的身份'), findsOneWidget);
      expect(ports.flows.length, 2);
      expect(auth.sends, 0);

      await tap(find.byTooltip('返回'));
      await key('settings-models');
      await key('voices-QWEN_OMNI_PLUS');
      expect(
        tester
            .widget<NativeVoiceSelectionRow>(
              find.byKey(const ValueKey('selectCloneVoice')),
            )
            .selected,
        isTrue,
      );
      await tap(find.byTooltip('删除当前模型克隆音色'));
      await tap(find.text('取消'));
      expect(ports.catalog.cloneAssets.length, 2);
      await tap(find.byTooltip('删除当前模型克隆音色'));
      await tap(find.text('确认删除'));
      expect(ports.catalog.cloneAssets, {'DOUBAO_SEEDUPLEX_3_0'});
      expect(ports.recording, isTrue);
      expect(find.text('当前模型暂无可用的克隆音色，完成声音克隆后即可使用'), findsOneWidget);
      await tap(
        find.descendant(
          of: find.byType(CallVoicesPage),
          matching: find.bySemanticsLabel('声音克隆，650积分'),
        ),
      );
      expect(find.text('选择声音克隆模型'), findsNothing);
      expect(find.text('声音克隆已完成'), findsOneWidget);
      expect(ports.flows.last.candidates.fromSaved, 1);
      expect(ports.flows.last.capture.captures, 0);
      await tap(find.text('设为默认声音'));
      await tap(find.text('完成并返回'));
      expect(
        container.read(callModelControllerProvider).voiceProvider,
        'QWEN_OMNI_PLUS',
      );
      expect(
        container.read(callModelControllerProvider).voices!.selectionMode,
        'CLONE',
      );
      await key('voices-QWEN_OMNI_PLUS');

      await key('backFromVoiceIdentity');
      await key('voices-DOUBAO_SEEDUPLEX_3_0');
      expect(
        tester
            .widget<NativeVoiceSelectionRow>(
              find.byKey(const ValueKey('selectCloneVoice')),
            )
            .selected,
        isTrue,
      );
      await key('backFromVoiceIdentity');
      await key('backFromVoiceModel');
      await key('settings-identity');
      await tap(find.byTooltip('编辑身份'));
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(const Key('identity-name')),
                matching: find.byType(TextField),
              ),
            )
            .readOnly,
        isTrue,
      );
      await tap(find.text('女'));
      await tap(find.text('保存'));
      expect(ports.identity.value.status, IdentityStatus.verified);
      expect(ports.identity.value.name, '演练用户');
      expect(ports.identity.value.gender, '女');

      await key('workbench-home');
      await key('scene-app');
      final fresh = ProviderScope.containerOf(
        tester.element(find.byType(PhoneAgentApp)),
      );
      final reset = fresh.read(cloneCreationPortProvider) as ShellClonePorts;
      expect(reset.catalog.cloneAssets, isEmpty);
      expect(reset.recording, isFalse);
      expect(reset.identity.value.status, IdentityStatus.filled);
      await key('workbench-home');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpUntilUiSettled();
      expect(tester.takeException(), isNull);
    });
  }
}
