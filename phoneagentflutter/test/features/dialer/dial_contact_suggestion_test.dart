import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/contacts/data/lpinyin_contact_dictionary.dart';
import 'package:phone_agent/features/contacts/domain/contact_records.dart';
import 'package:phone_agent/features/dialer/domain/dial_contact_suggestion.dart';

void main() {
  const policy = DialSuggestionPolicy(LpinyinContactDictionary());
  final rows = policy.index(const [
    DeviceContactRow(name: '号码匹配', phone: '+1 2025550974', contactId: 'n'),
    DeviceContactRow(name: '张三', phone: '+8613800100200', contactId: 'z'),
    DeviceContactRow(name: '张三', phone: '+8613900100200', contactId: 'z'),
    DeviceContactRow(name: '张三', phone: '+8613700100200', contactId: 'z2'),
  ]);
  test('name initials win over number matches and group by contact id', () {
    final items = DialSuggestionPolicy.search('97', rows);
    expect(items.map((i) => i.entry.row.contactId), ['z', 'z2', 'n']);
    expect(items.first.phone, '+8613800100200');
    expect(items.first.digitStart, isNull);
  });
  test('full pinyin prefix and latin tokens use ordinary T9', () {
    expect(DialSuggestionPolicy.search('94264', rows).length, 2);
    final english = policy.index(const [
      DeviceContactRow(name: 'Alice Bob', phone: '12345'),
    ]);
    expect(DialSuggestionPolicy.search('22', english), hasLength(1));
    expect(DialSuggestionPolicy.search('25423', english), hasLength(1));
    expect(DialSuggestionPolicy.search('423', english), isEmpty);
  });
  test(
    'number matches keep multiple numbers and exclude supported country code',
    () {
      expect(DialSuggestionPolicy.search('00100', rows).length, 3);
      expect(DialSuggestionPolicy.search('86138', rows), isEmpty);
      final item = DialSuggestionPolicy.search('555', rows).single;
      expect(item.display.text, '+1 202 555 0974');
      expect(
        item.display.text.substring(item.display.start!, item.display.end!),
        '555',
      );
    },
  );
  test('match spanning display separators retains accurate range', () {
    final item = DialSuggestionPolicy.search('202555', rows).single;
    expect(
      item.display.text.substring(item.display.start!, item.display.end!),
      '202 555',
    );
  });
  test('invalid queries and limits never expose a suggestion list', () {
    for (final query in ['', '*', '97#', '+86', '张三', '2 2']) {
      expect(DialSuggestionPolicy.search(query, rows), isEmpty);
    }
    expect(DialSuggestionPolicy.search('97', rows, limit: 0), isEmpty);
    expect(DialSuggestionPolicy.search('97', rows, limit: 2), hasLength(2));
  });
  test(
    'normalized international dialing source wins over local display number',
    () {
      final entries = policy.index(const [
        DeviceContactRow(
          name: 'Alice',
          phone: '(202) 555-0101',
          normalizedPhone: '+12025550101',
        ),
      ]);
      final result = DialSuggestionPolicy.search('555', entries).single;
      expect(result.phone, '+12025550101');
      expect(result.display.text, '+1 202 555 0101');
      final china = policy.index(const [
        DeviceContactRow(name: '张三', phone: '13800100200'),
      ]);
      expect(
        DialSuggestionPolicy.search('97', china).single.phone,
        '+8613800100200',
      );
    },
  );
  test('missing ids group by name and default cap is ten', () {
    final entries = policy.index([
      for (var i = 0; i < 20; i++)
        DeviceContactRow(name: 'Alice $i', phone: '2025550101'),
      const DeviceContactRow(name: 'Alice 0', phone: '2025550102'),
    ]);
    expect(DialSuggestionPolicy.search('2', entries), hasLength(10));
    expect(
      DialSuggestionPolicy.search('2', entries, limit: 100),
      hasLength(20),
    );
  });
  test('empty display name and raw number use valid normalized fallback', () {
    final entries = policy.index(const [
      DeviceContactRow(name: ' ', phone: '', normalizedPhone: '+12025550101'),
    ]);
    final result = DialSuggestionPolicy.search('555', entries).single;
    expect(result.name, '+12025550101');
    expect(result.phone, '+12025550101');
  });
  test('international formatting supports known and unknown prefixes', () {
    for (final pair in [
      ('008113456789', '+81 13 4567 89'),
      ('+44205550101', '+4420 5550 101'),
    ]) {
      final entry = policy.index([
        DeviceContactRow(name: '', phone: pair.$1),
      ]).single;
      expect(DialContactSuggestion(entry).display.text, pair.$2);
    }
  });
}
