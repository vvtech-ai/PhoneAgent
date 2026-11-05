import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/trusted_caller/data/trusted_identity_presentation_payload.dart';
import 'package:phone_agent/features/trusted_caller/domain/trusted_caller.dart';
import 'package:phone_agent/features/trusted_caller/domain/trusted_incoming_identity.dart';

void main() {
  const value = TrustedIncomingIdentity(
    owner: TrustedCallerOwner('synthetic', '12345678901', 7),
    eventId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    presentationRevision: 2,
    verification: TrustedIdentityVerification.verified,
    displayType: 1102,
    caller: '10987654321',
    target: '12345678901',
    sequence: 'synthetic',
    name: '合成身份',
    title: '头衔',
    department: '部门',
    position: '职务',
    company: '公司',
    job: '职业',
    school: '学校',
    serial: '序列',
    issuedAt: '时间',
    issuer: '机构',
    callTime: '来电时间',
    avatarData: [1, 2, 3],
  );
  test(
    'safe display snapshot roundtrip retains certificate and header fields',
    () {
      final payload = TrustedIdentityPresentationPayload.encode(value, 'test');
      final result = TrustedIdentityPresentationPayload.decode(payload)!;
      expect(
        TrustedIdentityPresentationPayload.encode(result, 'test'),
        payload,
      );
      expect(result.owner.matches(value.owner), isTrue);
      expect(result.avatarData, [1, 2, 3]);
    },
  );
  test(
    'invalid environment, malformed owner and stale revision are rejected',
    () {
      expect(
        TrustedIdentityPresentationPayload.decode(
          TrustedIdentityPresentationPayload.encode(value, 'local'),
        ),
        isNull,
      );
      final payload = TrustedIdentityPresentationPayload.encode(value, 'test');
      payload['presentationId'] = value.eventId;
      expect(TrustedIdentityPresentationPayload.decode(payload), isNull);
      payload['owner'] = {'accountId': 1};
      expect(TrustedIdentityPresentationPayload.decode(payload), isNull);
    },
  );
}
