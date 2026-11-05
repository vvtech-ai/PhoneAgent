import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/home/domain/home_config.dart';
import 'package:phone_agent/features/home/domain/home_card_preferences.dart';
import 'package:phone_agent/features/home/data/secure_home_card_preferences.dart';

HomeCard card(
  String id, {
  bool visible = true,
  HomeCardStatus status = HomeCardStatus.enabled,
}) => HomeCard(
  id: id,
  title: id,
  subtitle: '',
  status: status,
  action: HomeAction.genericTask,
  defaultVisible: visible,
);
void main() {
  test(
    'v66 published defaults, account overrides, new cards and disabled cards retain their exact order',
    () {
      final rows = [
        card('new'),
        card('a'),
        card('hidden', visible: false),
        card('disabled', status: HomeCardStatus.disabled),
        card('b'),
      ];
      var preferences = const HomeCardPreferences(
        order: ['b', 'a', 'removed', 'a'],
        visibility: {'a': false, 'disabled': true},
      );
      expect(
        HomeCardPreferencePolicy.ordered(rows, preferences).map((c) => c.id),
        ['new', 'hidden', 'b', 'a'],
      );
      expect(
        HomeCardPreferencePolicy.project(rows, preferences).map((c) => c.id),
        ['new', 'b'],
      );
      preferences = HomeCardPreferencePolicy.visibility(
        rows,
        preferences,
        'hidden',
        true,
      );
      preferences = HomeCardPreferencePolicy.move(rows, preferences, 2, 0);
      expect(
        HomeCardPreferencePolicy.project(rows, preferences).map((c) => c.id),
        ['b', 'new', 'hidden'],
      );
      expect(
        HomeCardPreferencePolicy.project(
          rows,
          const HomeCardPreferences(),
        ).map((c) => c.id),
        ['new', 'a', 'b'],
      );
    },
  );
  test('home preference keys never cross accounts or endpoints', () {
    expect(
      SecureHomeCardPreferences(['dev', 'a', 'one']).key,
      isNot(SecureHomeCardPreferences(['dev', 'a', 'two']).key),
    );
    expect(
      SecureHomeCardPreferences(['dev', 'a', 'one']).key,
      isNot(SecureHomeCardPreferences(['dev', 'b', 'one']).key),
    );
  });
}
