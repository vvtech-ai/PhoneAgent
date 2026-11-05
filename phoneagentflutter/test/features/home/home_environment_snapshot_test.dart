import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/home/data/dio_home_repository.dart';
import 'package:phone_agent/features/home/domain/home_card_preferences.dart';
import 'package:phone_agent/features/home/domain/home_config.dart';
import 'package:phone_agent/features/home/domain/home_defaults.dart';
import 'package:phone_agent/features/home/presentation/controller/home_controller.dart';
import 'home_snapshot_readiness_test.dart' show SnapshotStore, SnapshotNetwork;

void main() {
  test(
    'test offline snapshot is immediate and isolated from dev and prod',
    () async {
      final store = SnapshotStore()..readGate = Completer<String?>();
      final network = SnapshotNetwork();
      final repo = DioHomeRepository(
        AppConfig.parse(
          environment: 'test',
          apiBaseUrl: 'https://example.test/',
        ),
        store,
        client: Dio()..httpClientAdapter = network,
      );
      final home = HomeController(repo);
      addTearDown(() {
        home.dispose();
        repo.close();
      });
      unawaited(home.refresh());
      final config = home.state.config;
      expect(config.builtin, true);
      expect(
        config.cards
            .where((c) => c.status != HomeCardStatus.disabled)
            .map((c) => c.title)
            .toList(),
        ['实时翻译', '帮你订餐厅', '帮你活动邀约', '帮你销售推荐', '帮你会议邀请', '替你道歉', '挪车'],
      );
      expect(config.cards.map((c) => c.status).toList(), [
        ...List.filled(6, HomeCardStatus.enabled),
        HomeCardStatus.comingSoon,
        HomeCardStatus.disabled,
        HomeCardStatus.disabled,
      ]);
      for (final card in config.cards.where(
        (c) =>
            c.canEnter('1.0.54') &&
            c.action == HomeAction.skill &&
            c.skillId != 'apology_master',
      )) {
        expect(card.opening, isNotEmpty, reason: card.id);
      }
      expect(
        config.cards.singleWhere((c) => c.id == 'apology').opening,
        isEmpty,
        reason: 'apology keeps the existing dedicated consent flow',
      );
      expect(
        network.requests,
        isEmpty,
        reason: 'the initial frame does not wait for disk or network',
      );
      expect(bundledHomeFor(AppEnvironment.prod), same(builtinHome));
      expect(bundledHomeFor(AppEnvironment.dev), same(builtinHome));
      expect(bundledHomeFor(null), same(builtinHome));
      store.readGate!.complete(null);
      await network.started.future;
      repo.close();
    },
  );

  test(
    'published defaults do not reset user visibility or revive disabled cards',
    () {
      final cards = bundledHomeFor(AppEnvironment.test).cards;
      const preference = HomeCardPreferences(
        order: ['restaurant_booking', 'meeting_invite', 'sales_promotion'],
        visibility: {'restaurant_booking': false, 'meeting_invite': true},
      );
      final visible = HomeCardPreferencePolicy.project(cards, preference);
      expect(visible.any((c) => c.id == 'restaurant_booking'), false);
      expect(visible.any((c) => c.id == 'meeting_invite'), false);
      expect(visible.any((c) => c.id == 'simultaneous_interpretation'), true);
      expect(preference.order, [
        'restaurant_booking',
        'meeting_invite',
        'sales_promotion',
      ]);
    },
  );
}
