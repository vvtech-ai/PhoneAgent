import 'package:phone_agent/core/design/native_business_dialog.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/settings_providers.dart';
import 'package:phone_agent/features/settings/presentation/pages/settings_page.dart';
import 'package:phone_agent/features/settings/presentation/pages/original_audio_page.dart';
import 'package:phone_agent/features/settings/presentation/widgets/logout_dialog.dart';
import 'package:phone_agent/features/settings/presentation/widgets/native_original_audio_controls.dart';
import 'original_audio_test.dart' show MemoryAudioStore;

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('settings entries and original-audio page at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 680);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      final store = MemoryAudioStore();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [originalAudioStoreProvider.overrideWithValue(store)],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: SettingsPage(
                  developer: false,
                  modelSummary: '模型',
                  originalSummary: '关闭',
                  onOpen: (where) {
                    if (where == SettingsDestination.originalAudio) {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const OriginalAudioPage(),
                        ),
                      );
                    }
                  },
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('海外模型与服务区域'), findsNothing);
      expect(find.text('开发者功能'), findsNothing);
      expect(find.text('版本更新'), findsNothing);
      expect(find.text('记忆'), findsOneWidget);
      expect(find.text('可信来电MCP服务'), findsOneWidget);
      expect(find.text('SIP账号设置'), findsNothing);
      await tester.tap(find.text('实时翻译原音'));
      await tester.pumpAndSettle();
      expect(find.textContaining('尚未接入'), findsNothing);
      expect(find.textContaining('迁移进度'), findsNothing);
      expect(find.textContaining('仅影响下一通实时翻译通话'), findsOneWidget);
      expect(
        tester.widget<Slider>(find.byKey(const Key('original-gain'))).onChanged,
        isNull,
      );
      expect(
        tester
            .getSemantics(find.byKey(const Key('original-enabled')))
            .rect
            .width,
        48,
        reason: 'the toggle must not merge with the full settings card',
      );
      await tester.tap(find.byType(NativeAudioToggle));
      await tester.pumpAndSettle();
      final gain = tester.widget<Slider>(
        find.byKey(const Key('original-gain')),
      );
      gain.onChanged!(20);
      await tester.pumpAndSettle();
      expect(find.text('混声时原声比例：20%'), findsOneWidget);
      expect(store.value.gain, 20);
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(find.text('设置'), findsOneWidget);
      await tester.tap(find.text('实时翻译原音'));
      await tester.pumpAndSettle();
      expect(find.text('混声时原声比例：20%'), findsOneWidget);
      semantics.dispose();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('original audio remains operable at 320px and double font', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = MemoryAudioStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [originalAudioStoreProvider.overrideWithValue(store)],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: const OriginalAudioPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('original-enabled')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('original-gain')),
      100,
    );
    await tester.ensureVisible(find.byKey(const Key('original-gain')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('original-gain')),
      const Offset(-80, 0),
    );
    await tester.pumpAndSettle();
    expect(store.value.enabled, isTrue);
    expect(store.value.gain, lessThan(50));
    expect(store.value.gain % 10, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Android and unlocked menu are visible without adding deprecated options',
    (tester) async {
      SettingsDestination? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsPage(
              developer: true,
              modelSummary: '',
              originalSummary: '',
              onOpen: (value) => opened = value,
            ),
          ),
        ),
      );
      await tester.scrollUntilVisible(find.text('开发者功能'), 200);
      await tester.ensureVisible(find.byKey(const Key('settings-developer')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('开发者功能'));
      expect(opened, SettingsDestination.developer);
      expect(find.text('版本更新'), findsNothing);
      expect(find.text('常用联系方式'), findsNothing);
      expect(find.text('独立声音克隆'), findsNothing);
    },
  );
  testWidgets(
    'failed load and failed save can retry without discarding draft',
    (tester) async {
      final store = MemoryAudioStore()..readFails = true;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [originalAudioStoreProvider.overrideWithValue(store)],
          child: const MaterialApp(home: OriginalAudioPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('读取设置失败，请重试'), findsOneWidget);
      store.readFails = false;
      await tester.tap(find.text('重新读取'));
      await tester.pumpAndSettle();
      store.writeFails = true;
      await tester.tap(find.byType(NativeAudioToggle));
      await tester.pumpAndSettle();
      expect(find.text('设置尚未保存，请重试'), findsOneWidget);
      expect(
        tester.widget<NativeAudioToggle>(find.byType(NativeAudioToggle)).value,
        isTrue,
      );
      store.writeFails = false;
      await tester.tap(find.text('重试保存'));
      await tester.pumpAndSettle();
      expect(find.text('已保存在当前设备'), findsNothing);
      expect(find.text('设置尚未保存，请重试'), findsNothing);
      expect(store.value.enabled, isTrue);
      expect(
        tester.widget<NativeAudioToggle>(find.byType(NativeAudioToggle)).value,
        isTrue,
      );
    },
  );
  testWidgets(
    'logout cancel and system back never sign out; fail/retry single flight',
    (tester) async {
      var calls = 0;
      Completer<void>? pending;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showLogoutConfirmation(context, () async {
                  calls++;
                  await pending?.future;
                }),
                child: const Text('打开确认'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开确认'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.tap(find.text('打开确认'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.tap(find.text('打开确认'));
      await tester.pumpAndSettle();
      pending = Completer<void>();
      await tester.tap(find.byKey(const ValueKey('logout-confirm')));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('退出中…'), findsOneWidget);
      expect(calls, 1);
      pending.completeError(StateError('synthetic'));
      await tester.pumpAndSettle();
      expect(find.text('退出失败，请重试'), findsOneWidget);
      pending = null;
      await tester.tap(find.byKey(const ValueKey('logout-confirm')));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.byType(NativeBusinessDialog), findsNothing);
    },
  );
}
