import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/home_card_preference_providers.dart';
import 'package:phone_agent/features/home/domain/home_card_preferences.dart';
import 'package:phone_agent/features/home/domain/home_config.dart';
import 'package:phone_agent/features/home/presentation/controller/home_card_preference_controller.dart';
import 'package:phone_agent/features/home/presentation/controller/home_controller.dart';
import 'package:phone_agent/features/home/presentation/pages/home_card_preferences_route.dart';

const cards = [
  HomeCard(
    id: 'one',
    title: '卡片一',
    subtitle: '不应显示的说明',
    status: HomeCardStatus.enabled,
    action: HomeAction.skill,
  ),
  HomeCard(
    id: 'two',
    title: '卡片二',
    subtitle: '',
    status: HomeCardStatus.enabled,
    action: HomeAction.skill,
    defaultVisible: false,
  ),
  HomeCard(
    id: 'soon',
    title: '卡片三',
    subtitle: '不应显示的说明',
    status: HomeCardStatus.comingSoon,
    action: HomeAction.none,
  ),
];

class Store implements HomeCardPreferenceRepository {
  HomeCardPreferences value = const HomeCardPreferences();
  bool fail = false;
  int writes = 0;
  Completer<void>? pending;
  @override
  Future<HomeCardPreferences> read() async => value;
  @override
  Future<void> save(HomeCardPreferences next) async {
    writes++;
    await pending?.future;
    if (fail) throw StateError('synthetic failure');
    value = next;
  }
}

class Home implements HomeRepository {
  @override
  Future<HomeConfig> load() async =>
      const HomeConfig('v66', [HomeSlogan('s', '合成标题', '')], cards);
  @override
  Future<HomeSlogan> nextSlogan(HomeConfig c) async => c.slogans.first;
}

final epochProvider = StateProvider<int?>((ref) => 1);
Future<HomeCardPreferenceController> boot(
  WidgetTester tester,
  Store store,
  TargetPlatform platform,
  double scale,
) async {
  tester.view.physicalSize = const Size(320, 740);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final controller = HomeCardPreferenceController(store);
  await controller.load();
  final home = HomeController(Home());
  await home.refresh();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        loginEpochProvider.overrideWith((ref) => ref.watch(epochProvider)),
        homeControllerProvider.overrideWith((ref) => home),
        homeCardPreferenceProvider.overrideWith((ref) => controller),
      ],
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const HomeCardPreferencesRoute(ownerEpoch: 1),
                ),
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开'));
  await tester.pumpAndSettle();
  return controller;
}

Future<void> tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> dragSoonToTop(WidgetTester tester) async {
  final from = tester.getCenter(find.byKey(const ValueKey('skill-drag-soon')));
  final to = tester.getCenter(find.byKey(const ValueKey('skill-drag-one')));
  final gesture = await tester.startGesture(from);
  await tester.pump();
  for (var step = 1; step <= 12; step++) {
    await gesture.moveTo(
      Offset.lerp(from, to - const Offset(0, 50), step / 12)!,
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  test(
    'serialized commits preserve queued visibility and disposed queue cannot start writes',
    () async {
      final store = Store()..pending = Completer<void>();
      final c = HomeCardPreferenceController(store);
      await c.load();
      final one = c.visibility(cards, 'two', true);
      final two = c.visibility(cards, 'one', false);
      await Future<void>.delayed(Duration.zero);
      expect(c.preferences.visibility, isEmpty);
      expect(store.writes, 1);
      store.pending!.complete();
      await Future.wait([one, two]);
      expect(c.preferences.visibility, {'two': true, 'one': false});
      c.dispose();
      final blocked = Store()..pending = Completer<void>();
      final old = HomeCardPreferenceController(blocked);
      await old.load();
      final first = old.visibility(cards, 'two', true);
      final second = old.reset();
      await Future<void>.delayed(Duration.zero);
      old.dispose();
      blocked.pending!.complete();
      await Future.wait([first, second]);
      expect(blocked.writes, 1);
    },
  );
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '$platform $scale handle drag cancel failure retry and restore',
        (tester) async {
          final store = Store();
          final c = await boot(tester, store, platform, scale);
          expect(find.text('Skill 卡片'), findsOneWidget);
          expect(find.text('拖动以调整首页显示的卡片的顺序'), findsOneWidget);
          expect(find.text('不应显示的说明'), findsNothing);
          expect(find.text('即将提供'), findsOneWidget);
          expect(
            find.byType(ReorderableDelayedDragStartListener),
            findsNothing,
          );
          final restoreY = tester
              .getCenter(find.byKey(const Key('skill-restore')))
              .dy;
          store.fail = true;
          await tap(tester, find.byKey(const ValueKey('skill-visible-two')));
          expect(c.preferences.visibility, isEmpty);
          expect(find.text('设置未保存，请重试'), findsOneWidget);
          expect(
            tester
                .widget<CupertinoSwitch>(
                  find.byKey(const ValueKey('skill-visible-two')),
                )
                .value,
            isFalse,
          );
          store.fail = false;
          await tap(tester, find.byKey(const ValueKey('skill-visible-two')));
          expect(
            HomeCardPreferencePolicy.project(cards, c.preferences).length,
            3,
          );
          store.fail = true;
          await dragSoonToTop(tester);
          expect(c.preferences.order, isEmpty);
          expect(find.text('设置未保存，请重试'), findsOneWidget);
          store.fail = false;
          await dragSoonToTop(tester);
          expect(c.preferences.order.first, 'soon');
          expect(
            HomeCardPreferencePolicy.project(cards, c.preferences).first.id,
            'soon',
          );
          final before = store.writes;
          final cancel = await tester.startGesture(
            tester.getCenter(find.byKey(const ValueKey('skill-drag-soon'))),
          );
          await tester.pump();
          await cancel.moveBy(const Offset(0, 100));
          await tester.pump(const Duration(milliseconds: 250));
          await cancel.cancel();
          await tester.pumpAndSettle();
          expect(store.writes, before);
          expect(c.preferences.order.first, 'soon');
          expect(
            tester.getCenter(find.byKey(const Key('skill-restore'))).dy,
            restoreY,
          );
          await tap(tester, find.byKey(const Key('skill-restore')));
          expect(find.text('恢复默认设置？'), findsOneWidget);
          expect(find.text('将清除当前账号的卡片顺序和显示设置。'), findsOneWidget);
          await tap(tester, find.text('取消'));
          expect(store.writes, before);
          await tap(tester, find.byKey(const Key('skill-restore')));
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(store.writes, before);
          await tap(tester, find.byKey(const Key('skill-restore')));
          await tester.tapAt(const Offset(5, 5));
          await tester.pumpAndSettle();
          expect(store.writes, before);
          store.fail = true;
          await tap(tester, find.byKey(const Key('skill-restore')));
          await tap(tester, find.byKey(const Key('skill-restore-confirm')));
          expect(c.preferences.order.first, 'soon');
          expect(find.text('设置未保存，请重试'), findsOneWidget);
          store.fail = false;
          await tap(tester, find.byKey(const Key('skill-restore')));
          await tap(tester, find.byKey(const Key('skill-restore-confirm')));
          expect(c.preferences.order, isEmpty);
          expect(
            HomeCardPreferencePolicy.project(
              cards,
              c.preferences,
            ).map((card) => card.id),
            ['one', 'soon'],
          );
          expect(tester.takeException(), isNull);
          await tap(tester, find.byTooltip('返回'));
          expect(find.text('打开'), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );
    }
    testWidgets(
      '$platform account change closes restore dialog without saving',
      (tester) async {
        final store = Store();
        await boot(tester, store, platform, 1);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(HomeCardPreferencesRoute)),
        );
        await tap(tester, find.byKey(const Key('skill-restore')));
        container.read(epochProvider.notifier).state = 2;
        await tester.pumpAndSettle();
        expect(find.text('恢复默认设置？'), findsNothing);
        expect(find.text('打开'), findsOneWidget);
        expect(store.writes, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
