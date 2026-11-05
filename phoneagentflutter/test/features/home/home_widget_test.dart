import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/home/presentation/pages/home_page.dart';
import 'package:phone_agent/features/home/presentation/controller/home_controller.dart';
import 'package:phone_agent/features/home/domain/home_config.dart';
import '../../support/shell_fakes.dart';

void main() {
  test('refresh keeps one slogan for controller lifetime', () async {
    final repo = FakeHomeRepository();
    final c = HomeController(repo);
    await c.refresh();
    await c.refresh();
    expect(repo.loads, 2);
    expect(repo.rotations, 1);
    c.dispose();
  });
  testWidgets('disabled cards hidden and unsupported entries not actionable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var entries = 0;
    const config = HomeConfig(
      'test',
      [HomeSlogan('s', '标题', '副标题')],
      [
        HomeCard(
          id: 'hidden',
          title: '隐藏',
          subtitle: '隐藏',
          status: HomeCardStatus.disabled,
          action: HomeAction.none,
        ),
        HomeCard(
          id: 'future',
          title: '升级',
          subtitle: '升级',
          status: HomeCardStatus.enabled,
          action: HomeAction.genericTask,
          minimumVersion: '65.0.0',
        ),
        HomeCard(
          id: 'ready',
          title: '可用',
          subtitle: '可用',
          status: HomeCardStatus.enabled,
          action: HomeAction.genericTask,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomePage(
            state: const HomeState(config: config),
            modelName: '测试',
            onModels: () {},
            onRefresh: () async {},
            onEntry: (_) => entries++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('隐藏'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('skill-future')));
    expect(entries, 0);
    await tester.tap(find.byKey(const ValueKey('skill-ready')));
    expect(entries, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('small portrait remains scrollable without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomePage(
            state: const HomeState(),
            modelName: 'QwenOmniPlus',
            onModels: () {},
            onRefresh: () async {},
            onEntry: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
