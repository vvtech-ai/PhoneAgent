import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/contacts/domain/contact_phone_policy.dart';
import 'package:phone_agent/features/contacts/domain/contact_records.dart';

void main() {
  test('directory key matches v65 without becoming the system dial number', () {
    for (final value in [
      '+86 138-0000-0000',
      '008613800000000',
      '13800000000',
    ]) {
      expect(ContactPhonePolicy.directoryKey(value), '13800000000');
    }
    expect(ContactPhonePolicy.directoryKey('+65 6123 4567'), '6561234567');
  });
  test(
    'international countries and unknown country keep full lookup prefix',
    () {
      for (final (raw, country) in [
        ('+65 6123 4567', 'SG'),
        ('0081 90 12345678', 'JP'),
        ('+1 (212) 5550100', 'US'),
        ('+44 20 12345678', null),
      ]) {
        final value = ContactPhonePolicy.resolve(raw)!;
        expect(value.country, country);
        expect(value.lookup.startsWith('+'), isTrue);
        expect(value.dial, value.lookup);
      }
      expect(ContactPhonePolicy.resolve('+86'), isNull);
      expect(ContactPhonePolicy.resolve('+65 abc'), isNull);
    },
  );
  test(
    'Chinese E164 preserves original local landline zero and extensions',
    () {
      final fixed = ContactPhonePolicy.resolve(
        '0755-12345678',
        normalized: '+8675512345678',
      )!;
      expect(fixed.lookup, '075512345678');
      expect(fixed.dial, '+8675512345678');
      expect(
        ContactPhonePolicy.resolve('+86 13800000000')!.lookup,
        '13800000000',
      );
      expect(
        ContactPhonePolicy.resolve('0755-12345678转123')!.lookup,
        '075512345678-123',
      );
      expect(ContactPhonePolicy.resolve('123'), isNull);
    },
  );
  test(
    'rows preserve multiple numbers, de-duplicate and retain raw system dial',
    () {
      final rows = ContactRecord.fromRows(const [
        DeviceContactRow(name: '乙', phone: '13800000002'),
        DeviceContactRow(name: '甲', phone: '+86 13800000001'),
        DeviceContactRow(name: '甲', phone: '13800000001'),
        DeviceContactRow(name: '甲', phone: '+65 61234567'),
        DeviceContactRow(name: '', phone: '13800000003'),
        DeviceContactRow(name: '无号码', phone: ''),
      ]);
      expect(rows.length, 4);
      expect(rows.where((r) => r.name == '甲').length, 2);
      expect(
        rows.singleWhere((r) => r.phone == '13800000001').systemDialPhone,
        '+86 13800000001',
      );
      expect(rows.any((r) => r.name == '未知联系人'), isTrue);
      expect(() => rows.clear(), throwsUnsupportedError);
    },
  );
}
