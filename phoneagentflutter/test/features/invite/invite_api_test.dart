import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/invite/data/api_invite_repository.dart';
import 'package:phone_agent/features/invite/domain/invite.dart';
import 'package:phone_agent/features/invite/domain/invite_link_policy.dart';
import '../../support/synthetic_account_api.dart';

const policy = InviteLinkPolicy(
  host: 'example.test',
  path: '/invite/',
  scheme: 'phoneagent-test',
);
Map<String, Object?> activity() => {
  'periodId': 'p1',
  'name': '合成活动',
  'rulesTemplate': '仅新用户',
  'inviterPoints': 10,
  'inviteePoints': 20,
  'quotaPerInviter': 5,
  'fullBonusEnabled': false,
};
void main() {
  test(
    'personal eligibility never falls back to nominal campaign rewards',
    () async {
      final backend = SyntheticAccountApi()
        ..data = {
          'activity': {
            ...activity(),
            'fullBonusEnabled': true,
            'fullBonusThreshold': 5,
            'fullBonusPoints': 500,
          },
          'personal': {
            'grantsEligible': false,
            'successfulCount': 5,
            'inviterPoints': 0,
            'fullBonusPoints': 0,
            'fullBonusClaimed': true,
            'claimedFullBonusPoints': 0,
          },
        };
      final result = await ApiInviteRepository(backend.api, policy).activity();
      expect(result.inviterLabel, '当前账号不享受邀请赠分');
      expect(result.bonusLabel, '本期满邀已达标 · 无赠分');
      backend.data = {'activity': activity()};
      expect(
        (await ApiInviteRepository(
          backend.api,
          policy,
        ).activity()).inviterLabel,
        '个人奖励资格暂不可用',
      );
      backend.api.close();
    },
  );

  test(
    'protected invite reads use bearer and parse real activity fields',
    () async {
      final backend = SyntheticAccountApi()
        ..data = {'activity': activity(), 'personal': null};
      final repo = ApiInviteRepository(backend.api, policy);
      final result = await repo.activity();
      expect(result.activity!.inviteePoints, 20);
      expect(
        backend.requests.single.headers['Authorization'],
        'Bearer synthetic',
      );
      expect(backend.requests.single.uri.path, '/api/invite/activity');
      expect(result.personal, isNull);
      backend.api.close();
    },
  );
  test(
    'code rejects structurally invalid published URL; post has empty body',
    () async {
      final backend = SyntheticAccountApi()
        ..data = {
          'code': 'ABCD',
          'shareUrl': 'https://user@published.test/invite/?code=ABCD',
          'expiresAt': '2030-01-01',
          'confirmedUsed': 0,
          'reservedCount': 0,
          'available': 5,
          'activity': activity(),
        };
      final repo = ApiInviteRepository(backend.api, policy);
      await expectLater(repo.code(), throwsA(isA<InviteFailure>()));
      expect(backend.requests.single.method, 'POST');
      expect(backend.requests.single.data, isEmpty);
      backend.api.close();
    },
  );
  test(
    'trusted API published host differs from strict incoming link policy',
    () async {
      final backend = SyntheticAccountApi()
        ..data = {
          'code': 'ABCD',
          'shareUrl': 'https://published.test/web/invite/?code=ABCD',
          'expiresAt': '2030-01-01',
          'confirmedUsed': 0,
          'reservedCount': 0,
          'available': 5,
          'activity': activity(),
        };
      final result = await ApiInviteRepository(backend.api, policy).code();
      expect(result.code, 'ABCD');
      expect(policy.parse(result.url), isNull);
      backend.api.close();
    },
  );
  for (final url in [
    'http://published.test/invite/?code=ABCD',
    'https://published.test:444/invite/?code=ABCD',
    'https://published.test/invite/?code=EFGH',
    'https://published.test/invite/?code=ABCD#fragment',
  ]) {
    test(
      'published URL rejects invalid structure or mismatched code $url',
      () async {
        final backend = SyntheticAccountApi()
          ..data = {
            'code': 'ABCD',
            'shareUrl': url,
            'expiresAt': '2030-01-01',
            'confirmedUsed': 0,
            'reservedCount': 0,
            'available': 5,
            'activity': activity(),
          };
        await expectLater(
          ApiInviteRepository(backend.api, policy).code(),
          throwsA(isA<InviteFailure>()),
        );
        backend.api.close();
      },
    );
  }
  test('cursor pagination and operation events preserve contract', () async {
    final backend = SyntheticAccountApi()
      ..data = {
        'items': [
          {
            'id': 'r',
            'inviteePhone': '13800000000',
            'registeredAt': '2026-10-05',
            'inviterPoints': 10,
            'fullBonusPoints': 2,
          },
        ],
        'total': 1,
        'nextCursor': '',
      };
    final repo = ApiInviteRepository(backend.api, policy);
    final records = await repo.records('cursor-a');
    expect(records.items.single.points, 12);
    expect(records.items.single.maskedPhone, '138****0000');
    expect(backend.requests.single.uri.queryParameters, {
      'cursor': 'cursor-a',
      'size': '20',
    });
    backend.data = <String, Object?>{};
    await repo.event('p1', 'COPY_LINK', 'e1');
    expect(backend.requests.last.data, {
      'periodId': 'p1',
      'type': 'COPY_LINK',
      'eventId': 'e1',
    });
    await expectLater(
      repo.event('p1', 'GRANT_POINTS', 'e2'),
      throwsA(isA<InviteFailure>()),
    );
    backend.api.close();
  });
  test(
    'code without activity is rejected even with valid published link',
    () async {
      final backend = SyntheticAccountApi()
        ..data = {
          'code': 'ABCD',
          'shareUrl': 'https://published.test/web/invite/?code=ABCD',
          'expiresAt': '2030-01-01',
          'confirmedUsed': 0,
          'reservedCount': 0,
          'available': 5,
        };
      addTearDown(backend.api.close);
      await expectLater(
        ApiInviteRepository(backend.api, policy).code(),
        throwsA(
          isA<InviteFailure>().having(
            (e) => e.code,
            'code',
            'INVITE_ACTIVITY_CHANGED',
          ),
        ),
      );
    },
  );
  for (final rawActivity in [
    <String, Object?>{},
    {...activity(), 'periodId': ''},
    {...activity(), 'periodId': '   '},
  ]) {
    test(
      'incomplete activity identity revokes otherwise valid code $rawActivity',
      () async {
        final backend = SyntheticAccountApi()
          ..data = {
            'code': 'ABCD',
            'shareUrl': 'https://published.test/web/invite/?code=ABCD',
            'expiresAt': '2030-01-01',
            'confirmedUsed': 0,
            'reservedCount': 0,
            'available': 5,
            'activity': rawActivity,
          };
        addTearDown(backend.api.close);
        await expectLater(
          ApiInviteRepository(backend.api, policy).code(),
          throwsA(
            isA<InviteFailure>().having(
              (e) => e.code,
              'code',
              'INVITE_ACTIVITY_CHANGED',
            ),
          ),
        );
      },
    );
  }
  for (final code in ['ACTIVITY_DISABLED', 'ACTIVITY_UNAVAILABLE']) {
    test('closed activity exposes safe code $code', () async {
      final backend = SyntheticAccountApi()
        ..status = 409
        ..data = {'errorCode': code};
      addTearDown(backend.api.close);
      await expectLater(
        ApiInviteRepository(backend.api, policy).code(),
        throwsA(isA<InviteFailure>().having((e) => e.code, 'code', code)),
      );
    });
  }
  test('nested backend errors are exposed only as allowlisted codes', () async {
    final backend = SyntheticAccountApi()
      ..status = 409
      ..data = {'errorCode': 'INVITE_ACTIVITY_CHANGED'};
    await expectLater(
      ApiInviteRepository(backend.api, policy).code(),
      throwsA(
        isA<InviteFailure>().having(
          (e) => e.code,
          'code',
          'INVITE_ACTIVITY_CHANGED',
        ),
      ),
    );
    backend.api.close();
  });
}
