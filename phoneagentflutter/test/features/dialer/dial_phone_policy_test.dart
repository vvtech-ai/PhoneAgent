import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/dialer/domain/contact_dial_input.dart';
import 'package:phone_agent/features/dialer/domain/dial_country.dart';
import 'package:phone_agent/features/dialer/domain/dial_phone_policy.dart';

void main() {
  test('four supported countries searchable by name, pinyin, code', () {
    expect(dialCountries.map((c) => c.iso), ['CN', 'JP', 'SG', 'US']);
    expect(dialCountry('SG')!.matches('xjp'), isTrue);
    expect(dialCountry('JP')!.matches('RIben'), isTrue);
    expect(dialCountry('CN')!.matches('+86'), isTrue);
    expect(dialCountry('US')!.matches('美国'), isTrue);
    expect(dialCountry('CA'), isNull);
  });
  final cases = <(String, String, String)>[
    ('13800138000', 'CN', '+8613800138000'),
    ('008613800138000', 'CN', '+8613800138000'),
    ('8613800138000', 'CN', '+8613800138000'),
    ('01012345678', 'CN', '+861012345678'),
    ('+86 10 12345678', 'CN', '+861012345678'),
    ('4001234567', 'CN', '4001234567'),
    ('95588', 'CN', '95588'),
    ('10086', 'CN', '10086'),
    ('12345', 'CN', '12345'),
    ('09012345678', 'JP', '+819012345678'),
    ('61234567', 'SG', '+6561234567'),
    ('2025550123', 'US', '+12025550123'),
    ('0012025550123', 'CN', '+12025550123'),
  ];
  for (final (raw, iso, result) in cases) {
    test(
      'resolve $iso $raw',
      () => expect(DialPhonePolicy.resolve(raw, iso)?.number, result),
    );
  }
  test('extensions separated without auto DTMF', () {
    final target = DialPhonePolicy.resolve('01012345678转123', 'CN')!;
    expect(target.number, '+861012345678');
    expect(target.extension, '123');
  });
  test('empty, too short, unsupported country are rejected', () {
    for (final input in ['', '+', '12']) {
      expect(DialPhonePolicy.resolve(input, 'CN'), isNull);
    }
    expect(DialPhonePolicy.resolve('13800138000', 'CA'), isNull);
  });
  test('contact country detection and mainland fixed-line trunk', () {
    expect(contactDialInput('+86 (10) 12345678'), (
      iso: 'CN',
      number: '01012345678',
      error: '',
    ));
    expect(contactDialInput('0081 90 1234 5678'), (
      iso: 'JP',
      number: '9012345678',
      error: '',
    ));
    expect(contactDialInput('+1 202-555-0123').iso, 'US');
    expect(contactDialInput('+1 416-555-0123').error, contains('暂不支持'));
    expect(contactDialInput('+44 20 1234 5678').error, contains('暂不支持'));
  });
  test('contact invalid input does not become a URI or a partial number', () {
    for (final raw in [
      '',
      '+',
      '00',
      '12+34',
      'tel:10086',
      '10086;123',
      '10*086',
      'abc',
    ]) {
      expect(contactDialInput(raw).error, isNotEmpty, reason: raw);
    }
    expect(contactDialInput('123456789012345').error, contains('14'));
  });
  test('display grouping does not mutate control sequences', () {
    expect(DialPhonePolicy.display('13800138000', 'CN'), '138 0013 8000');
    expect(DialPhonePolicy.display('2025550123', 'US'), '202 555 0123');
    expect(DialPhonePolicy.display('61234567', 'SG'), '6123 4567');
    expect(DialPhonePolicy.display('20142014*#', 'CN'), '20142014*#');
  });
}
