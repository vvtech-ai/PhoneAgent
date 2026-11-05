import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/outbound_number_providers.dart';
import 'package:phone_agent/app/settings_providers.dart';
import 'package:phone_agent/app/translation_access_providers.dart';
import 'package:phone_agent/features/settings/data/preview_outbound_number_repository.dart';
import 'package:phone_agent/features/settings/domain/outbound_number.dart';
import 'package:phone_agent/features/settings/presentation/pages/developer_tools_route.dart';
import 'package:phone_agent/features/settings/presentation/pages/outbound_number_page.dart';
import 'package:phone_agent/features/settings/presentation/controller/outbound_number_controller.dart';
import 'package:phone_agent/core/design/native_gradient_action.dart';
import 'outbound_number_test.dart' show DelayedOutbound;

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('$platform outbound form readable at 320 and $scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 480);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(320, 480),
                textScaler: TextScaler.linear(scale),
              ),
              child: OutboundNumberPage(
                state: const OutboundNumberState(
                  saved: OutboundNumber('13800000000', configured: true),
                  draft: '13800000000',
                ),
                onEdit: (_) {},
                onLoad: () async => false,
                onSave: () async => false,
                onDelete: () async => false,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final title = tester.widget<Text>(find.text('固定外呼号码'));
        expect(title.maxLines, 1);
        expect(title.overflow, TextOverflow.ellipsis);
        expect(tester.getTopLeft(find.byType(TextField)).dx, 14);
        expect(tester.getSize(find.byType(TextField)).width, 292);
        for (final label in ['保存', '删除固定外呼号码']) {
          final action = find.ancestor(
            of: find.text(label),
            matching: find.byType(NativeGradientAction),
          );
          await tester.ensureVisible(action);
          await tester.pumpAndSettle();
          expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
          expect(tester.getSize(action).width, 292);
          expect(tester.widget<Text>(find.text(label)).maxLines, isNull);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  Future<void> press(WidgetTester tester, String label) async {
    final finder = find.text(label);
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> open(
    WidgetTester tester,
    OutboundNumberRepository repository, {
    bool unlocked = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          outboundNumberRepositoryProvider.overrideWithValue(repository),
          developerModeProvider.overrideWith((_) => unlocked),
          translationTestControlsProvider.overrideWithValue(false),
        ],
        child: const MaterialApp(home: DeveloperToolsRoute()),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 430.0]) {
    testWidgets('formal save/delete/summary and draft cancel at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = PreviewOutboundNumberRepository();
      await open(tester, repository);
      await press(tester, '固定外呼号码');
      await tester.enterText(find.byType(TextField), '＋１ （２０２）５５５－０１２３');
      await press(tester, '保存');
      expect(find.text('当前生效：+12025550123'), findsOneWidget);
      expect(repository.saves, 1);
      await press(tester, '固定外呼号码');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '+12025550123',
      );
      await tester.enterText(find.byType(TextField), 'unsaved');
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      await press(tester, '固定外呼号码');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '+12025550123',
      );
      await press(tester, '删除固定外呼号码');
      expect(find.text('尚未配置固定外呼号码'), findsOneWidget);
      expect(repository.deletes, 1);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('read failure, explicit reload and failed writes stay on form', (
    tester,
  ) async {
    final repository = PreviewOutboundNumberRepository(number: '2025550123')
      ..failRead = true;
    await open(tester, repository);
    await press(tester, '固定外呼号码');
    expect(find.textContaining('加载失败'), findsOneWidget);
    repository.failRead = false;
    await press(tester, '重新读取');
    expect(find.text('删除固定外呼号码'), findsOneWidget);
    repository.failWrite = true;
    await tester.enterText(find.byType(TextField), '202-555-0124');
    await press(tester, '保存');
    expect(find.textContaining('保存结果未确认'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '202-555-0124',
    );
    expect(repository.saves, 1);
    await press(tester, '删除固定外呼号码');
    expect(find.textContaining('删除结果未确认'), findsOneWidget);
    expect(repository.deletes, 1);
    repository.failWrite = false;
    await press(tester, '保存');
    expect(find.text('当前生效：2025550124'), findsOneWidget);
  });
  testWidgets(
    'pending response after leaving editor cannot pop developer route',
    (tester) async {
      final repository = DelayedOutbound();
      await open(tester, repository);
      await press(tester, '固定外呼号码');
      await tester.enterText(find.byType(TextField), '2025550123');
      await tester.tap(find.text('保存'));
      await tester.pump();
      expect(find.text('保存中...'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      repository.gate.complete(
        const OutboundNumber('2025550123', configured: true),
      );
      await tester.pumpAndSettle();
      expect(find.text('开发者功能'), findsOneWidget);
      expect(find.text('当前生效：2025550123'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(repository.saves, 1);
    },
  );
  testWidgets(
    'account dependency change clears draft and ignores old write effect',
    (tester) async {
      final old = DelayedOutbound();
      final next = PreviewOutboundNumberRepository(number: '2025550124');
      final selected = StateProvider<OutboundNumberRepository>((_) => old);
      final container = ProviderContainer(
        overrides: [
          outboundNumberRepositoryProvider.overrideWith(
            (ref) => ref.watch(selected),
          ),
          developerModeProvider.overrideWith((_) => true),
          translationTestControlsProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: DeveloperToolsRoute()),
        ),
      );
      await tester.pumpAndSettle();
      await press(tester, '固定外呼号码');
      await tester.enterText(find.byType(TextField), '2025550123');
      await tester.tap(find.text('保存'));
      await tester.pump();
      container.read(selected.notifier).state = next;
      await tester.pumpAndSettle();
      old.gate.complete(const OutboundNumber('2025550123', configured: true));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '2025550124',
      );
      expect(find.text('固定外呼号码已保存'), findsNothing);
      expect(next.saves, 0);
    },
  );
  testWidgets('locked developer page never starts account request', (
    tester,
  ) async {
    final repository = PreviewOutboundNumberRepository();
    await open(tester, repository, unlocked: false);
    expect(repository.reads, 0);
    expect(find.text('固定外呼号码'), findsNothing);
  });
}
