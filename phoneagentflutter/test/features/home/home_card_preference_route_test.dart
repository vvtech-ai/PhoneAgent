import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
    id: 'shown',
    title: '默认显示',
    subtitle: '',
    status: HomeCardStatus.enabled,
    action: HomeAction.skill,
  ),
  HomeCard(
    id: 'hidden',
    title: '默认隐藏',
    subtitle: '',
    status: HomeCardStatus.enabled,
    action: HomeAction.skill,
    defaultVisible: false,
  ),
];

class _Store implements HomeCardPreferenceRepository {
  HomeCardPreferences value = const HomeCardPreferences();
  Completer<HomeCardPreferences>? pending;
  bool failed = false;
  @override
  Future<HomeCardPreferences> read() async {
    if (failed) throw StateError('read');
    return pending == null ? value : pending!.future;
  }

  @override
  Future<void> save(HomeCardPreferences value) async {
    this.value = value;
  }
}

class _Home implements HomeRepository {
  @override
  Future<HomeConfig> load() async =>
      const HomeConfig('v66', [HomeSlogan('s', '标题', '')], cards);
  @override
  Future<HomeSlogan> nextSlogan(HomeConfig c) async => c.slogans.first;
}

void main() {
  testWidgets('card visibility, ordering and reset render published defaults', (
    tester,
  ) async {
    final store = _Store();
    final c = HomeCardPreferenceController(store);
    await c.load();
    final home = HomeController(_Home());
    await home.refresh();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          loginEpochProvider.overrideWithValue(1),
          homeControllerProvider.overrideWith((ref) => home),
          homeCardPreferenceProvider.overrideWith((ref) => c),
        ],
        child: const MaterialApp(home: HomeCardPreferencesRoute(ownerEpoch: 1)),
      ),
    );
    expect(
      tester
          .widget<CupertinoSwitch>(
            find.byKey(const ValueKey('skill-visible-hidden')),
          )
          .value,
      isFalse,
    );
    await tester.tap(find.byKey(const ValueKey('skill-visible-hidden')));
    await tester.pumpAndSettle();
    expect(HomeCardPreferencePolicy.project(cards, c.preferences).length, 2);
    await c.move(cards, 1, 0);
    await tester.pump();
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('hidden'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey('shown'))).dy),
    );
    await tester.tap(find.text('恢复默认'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(store.value.order, isNotEmpty);
    await tester.tap(find.text('恢复默认'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('skill-restore-confirm')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CupertinoSwitch>(
            find.byKey(const ValueKey('skill-visible-hidden')),
          )
          .value,
      isFalse,
    );
    expect(store.value.order, isEmpty);
    expect(tester.takeException(), isNull);
  });
  test(
    'late loading never overwrites edits; successful read retry clears notice',
    () async {
      final store = _Store()..pending = Completer<HomeCardPreferences>();
      final c = HomeCardPreferenceController(store);
      final reading = c.load();
      final writing = c.visibility(cards, 'hidden', true);
      store.pending!.complete(
        const HomeCardPreferences(visibility: {'shown': false}),
      );
      await reading;
      await writing;
      expect(HomeCardPreferencePolicy.project(cards, c.preferences).length, 2);
      store.pending = null;
      store.failed = true;
      await c.load();
      expect(c.notice, isNotEmpty);
      store.failed = false;
      await c.load();
      expect(c.notice, isEmpty);
      c.dispose();
    },
  );
}
