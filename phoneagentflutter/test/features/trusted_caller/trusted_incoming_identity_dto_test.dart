import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/trusted_caller/domain/trusted_caller.dart';
import 'package:phone_agent/features/trusted_caller/domain/trusted_incoming_identity.dart';
import 'package:phone_agent/features/trusted_caller/data/trusted_incoming_identity_dto.dart';

void main() {
  const owner = TrustedCallerOwner('synthetic', 'synthetic-phone', 1);
  Map<String, Object?> report({String phase = 'pending'}) => {
    'owner': {
      'accountId': owner.accountId,
      'phone': owner.phone,
      'loginEpoch': 1,
      'environment': 'test',
    },
    'eventId': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
    'activityFresh': false,
    'identity': <String, Object?>{
      'verification': phase,
      'phoneno': '12025550100',
      'targetNumber': 'synthetic-phone',
      'sequence': 'synthetic-sequence',
    },
  };
  TrustedIncomingIdentity? decode(Object? value) =>
      TrustedIncomingIdentityDto.decode(
        value,
        owner: owner,
        environment: 'test',
      );
  test(
    'presentation revision is integer and supports explicit notification click',
    () {
      for (final invalid in [-1, 1.0, true, '1', 2147483648]) {
        expect(
          decode(report(phase: 'verified')..['presentationRevision'] = invalid),
          isNull,
        );
      }
      expect(
        decode(report()..['presentationRevision'] = 1)?.presentationRevision,
        1,
      );
      expect(
        decode(
          report(phase: 'verified')..['presentationRevision'] = 1,
        )?.presentationId,
        'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee:1',
      );
    },
  );
  test('only explicit supported verification allows certificate', () {
    for (final phase in TrustedIdentityVerification.values) {
      final value = decode(report(phase: phase.name));
      expect(value?.verification, phase);
      expect(
        value?.hasCertificate,
        phase == TrustedIdentityVerification.verified,
      );
    }
    final unknown = report(phase: 'authorized');
    expect(decode(unknown), isNull);
    final pending = report();
    (pending['identity'] as Map)['signStaus'] = '1';
    (pending['identity'] as Map)['authorized'] = true;
    expect(decode(pending)?.hasCertificate, false);
  });
  test(
    'only bounded native image bytes are copied and URL fields are ignored',
    () {
      final value = report(phase: 'verified');
      final image = Uint8List.fromList([1, 2, 3]);
      (value['identity'] as Map)['avatarData'] = image;
      final decoded = decode(value)!;
      image[0] = 9;
      expect(decoded.avatarData, [1, 2, 3]);
      expect(() => decoded.avatarData[0] = 4, throwsUnsupportedError);
      for (final invalid in [
        Uint8List(32769),
        [1, 2],
        'https://private.invalid',
      ]) {
        (value['identity'] as Map)['avatarData'] = invalid;
        expect(decode(value)?.avatarData, isEmpty);
      }
    },
  );
  test('owner environment and event identity are strict', () {
    for (final key in ['accountId', 'phone', 'loginEpoch', 'environment']) {
      final value = report();
      (value['owner'] as Map)[key] = 'foreign';
      expect(decode(value), isNull);
    }
    for (final invalid in [null, '', 42, 'arbitrary']) {
      final value = report()..['eventId'] = invalid;
      expect(decode(value), isNull);
    }
    final wrongEpoch = report();
    (wrongEpoch['owner'] as Map)['loginEpoch'] = 1.0;
    expect(decode(wrongEpoch), isNull);
  });
  test('type six and pending cannot claim certified fresh activity', () {
    final value = report(phase: 'verified');
    (value['identity'] as Map)['showType'] = '6';
    expect(
      decode(value)?.verification,
      TrustedIdentityVerification.uncertified,
    );
    expect(decode(value)?.hasCertificate, false);
    value['activityFresh'] = true;
    expect(
      decode(value)?.verification,
      TrustedIdentityVerification.uncertified,
    );
    final pending = report()..['activityFresh'] = true;
    expect(decode(pending), isNull);
  });
  test(
    'display whitelist keeps aliases and drops raw data, URL and bad values',
    () {
      final value = report(phase: 'verified');
      final identity = value['identity'] as Map<String, Object?>;
      identity.addAll({
        'userName': '合成姓名',
        'dept': '合成部门',
        'jobTitle': '合成职位',
        'companyName': '合成企业',
        'UniqueID': 'synthetic-serial',
        'caName': '合成颁发机构',
        'token': 'synthetic-opaque',
        'avatarUrl': 'https://synthetic.invalid',
        'title': 'inside\ncontrol',
      });
      final decoded = decode(value)!;
      expect(decoded.name, '合成姓名');
      expect(decoded.department, '合成部门');
      expect(decoded.serial, 'synthetic-serial');
      expect(decoded.issuer, '合成颁发机构');
      expect(decoded.title, isEmpty);
    },
  );
  test('display called number must still belong to current owner', () {
    final value = report(phase: 'verified');
    (value['identity'] as Map)['targetNumber'] = 'other-phone';
    expect(decode(value), isNull);
    const phoneOwner = TrustedCallerOwner('synthetic', '+86 13800000000', 1);
    final normalized = report(phase: 'verified');
    (normalized['owner'] as Map)['phone'] = phoneOwner.phone;
    (normalized['identity'] as Map)['targetNumber'] = '13800000000';
    expect(
      TrustedIncomingIdentityDto.decode(
        normalized,
        owner: phoneOwner,
        environment: 'test',
      )?.hasCertificate,
      true,
    );
  });

  test('missing or malformed event clears existing display', () {
    expect(decode(null), isNull);
    expect(decode({'identity': 42}), isNull);
    final value = report();
    (value['identity'] as Map).remove('sequence');
    expect(decode(value), isNull);
    value['activityFresh'] = 'false';
    expect(decode(value), isNull);
  });
}
