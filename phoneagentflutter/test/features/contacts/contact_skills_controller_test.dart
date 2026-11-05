import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/app_update/domain/app_update.dart';
import 'package:phone_agent/features/contacts/presentation/controller/contact_skills_controller.dart';
import 'package:phone_agent/features/home/domain/home_config.dart';

const _slogan = HomeSlogan('s', '合成', '');
HomeCard card(
  String id, {
  String? minimum,
  HomeAction action = HomeAction.skill,
  HomeCardStatus status = HomeCardStatus.enabled,
}) => HomeCard(
  id: id,
  title: id,
  subtitle: '',
  status: status,
  action: action,
  skillId: id,
  minimumVersion: minimum,
);

class _Home implements HomeRepository {
  List<HomeCard> cards = [];
  bool fail = false;
  int calls = 0;
  Completer<HomeConfig>? gate;
  @override
  Future<HomeConfig> load() async {
    calls++;
    if (fail) throw StateError('synthetic');
    return gate?.future ?? HomeConfig('synthetic', [_slogan], cards);
  }

  @override
  Future<HomeSlogan> nextSlogan(HomeConfig config) async => _slogan;
}

class _Version implements InstalledAppSource {
  String version = '2.0.0';
  bool fail = false;
  int calls = 0;
  @override
  Future<InstalledApp> read() async {
    calls++;
    if (fail) throw StateError('synthetic');
    return InstalledApp('com.synthetic.test', version, 1);
  }
}

void main() {
  test(
    'actual installed version gates OpenSkill; builtin ungated needs no device IO',
    () async {
      final home = _Home()
        ..cards = [
          card('ungated'),
          card('current', minimum: '2.0.0'),
          card('future', minimum: '3.0.0'),
          card('translation', action: HomeAction.translation),
          card('disabled', status: HomeCardStatus.disabled),
        ];
      final version = _Version();
      final c = ContactSkillsController(home, version);
      addTearDown(c.dispose);
      await c.load();
      expect(c.state.cards.map((e) => e.id), [
        'ungated',
        'current',
        'translation',
      ]);
      version.version = '3.0.0';
      await c.load();
      expect(c.state.cards.map((e) => e.id), [
        'ungated',
        'current',
        'future',
        'translation',
      ]);
      home.cards = [card('ungated')];
      await c.load();
      expect(version.calls, 2);
    },
  );
  test(
    'failed version never guesses eligibility; retry restores gated card',
    () async {
      final home = _Home()
        ..cards = [card('ungated'), card('gated', minimum: '1.0.0')];
      final version = _Version()..fail = true;
      final c = ContactSkillsController(home, version);
      addTearDown(c.dispose);
      await c.load();
      expect(c.state.cards.map((e) => e.id), ['ungated']);
      expect(c.state.error, isNotEmpty);
      version.fail = false;
      await c.load();
      expect(c.state.cards.length, 2);
      expect(c.state.error, isEmpty);
      version.version = '';
      await c.load();
      expect(c.state.cards.map((e) => e.id), ['ungated']);
      expect(c.state.error, isNotEmpty);
    },
  );
  test(
    'directory error is retryable; single flight and disposed late reply are safe',
    () async {
      final home = _Home()..fail = true;
      final c = ContactSkillsController(home, _Version());
      await c.load();
      expect(c.state.error, isNotEmpty);
      home.fail = false;
      home.gate = Completer<HomeConfig>();
      final pending = c.load();
      await c.load();
      expect(home.calls, 2);
      expect(c.state.loading, isTrue);
      c.dispose();
      home.gate!.complete(HomeConfig('synthetic', [_slogan], [card('late')]));
      await pending;
      await c.load();
      expect(home.calls, 2);
    },
  );
}
