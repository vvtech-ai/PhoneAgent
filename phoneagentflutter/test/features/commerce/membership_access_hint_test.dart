import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/domain/membership_access_hint.dart';

void main() {
  test('required levels come from published capabilities, not rank', () {
    final hint = MembershipAccessHint.model(
      current: {'modelEntitlements': <Object?>[]},
      published: {
        'BASIC': {
          'modelEntitlements': [
            {'modelId': 'm', 'capability': 'REALTIME_VOICE'},
          ],
        },
        'PREMIUM': {'modelEntitlements': <Object?>[]},
      },
      modelId: 'm',
    );
    expect(hint.allowed, false);
    expect(hint.message, contains('初级会员'));
    expect(hint.message, isNot(contains('高级')));
  });
  test('missing benefits do not claim a membership denial', () {
    expect(
      MembershipAccessHint.model(
        current: null,
        published: {},
        modelId: 'm',
      ).allowed,
      isNull,
    );
    expect(
      MembershipAccessHint.model(
        current: {},
        published: {},
        modelId: 'm',
      ).allowed,
      isNull,
    );
  });
  test(
    'published same tier does not promise an upgrade unlocks old snapshot',
    () {
      final hint = MembershipAccessHint.model(
        current: {'modelEntitlements': <Object?>[]},
        published: {
          'PLUS': {
            'modelEntitlements': [
              {'modelId': 'm', 'capability': 'REALTIME_VOICE'},
            ],
          },
        },
        modelId: 'm',
        currentLevel: 'PLUS',
      );
      expect(hint.message, '当前套餐未包含此模型，请查看会员权益');
    },
  );
  test('actual current benefits take precedence over tier marketing', () {
    final hint = MembershipAccessHint.model(
      current: {
        'modelEntitlements': [
          {'modelId': 'm', 'capability': 'REALTIME_VOICE'},
        ],
      },
      published: {},
      modelId: 'm',
    );
    expect(hint.allowed, true);
    expect(hint.message, isEmpty);
  });
}
