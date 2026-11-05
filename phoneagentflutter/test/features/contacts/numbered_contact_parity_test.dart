import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/contacts/data/lpinyin_contact_dictionary.dart';
import 'package:phone_agent/features/contacts/domain/contact_name_matcher.dart';
import 'package:phone_agent/features/contacts/domain/contact_records.dart';

void main() {
  for (final query in ['小4', '小四']) {
    test('ASR $query preserves spoken digit identity', () {
      final matcher = ContactNameMatcher([
        for (final digit in ['4', '5', '6'])
          DeviceContactRow(name: '小$digit', phone: '1380000000$digit'),
      ], const LpinyinContactDictionary());
      final result = matcher.resolve([query], ContactInputSource.asr).single;
      expect(
        (result['candidates'] as List? ?? []).map((m) => m['displayName']),
        ['小4'],
      );
      if (query == '小四') expect(result['status'], 'MULTIPLE_CANDIDATES');
    });
  }
}
