import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/contacts/data/lpinyin_contact_dictionary.dart';
import 'package:phone_agent/features/contacts/domain/contact_name_matcher.dart';
import 'package:phone_agent/features/contacts/domain/contact_pinyin_search.dart';
import 'package:phone_agent/features/contacts/domain/contact_records.dart';

void main() {
  const dictionary = LpinyinContactDictionary();
  DeviceContactRow row(String name, String phone) => DeviceContactRow(
    name: name,
    phone: phone,
    contactId: 'synthetic',
    label: '工作',
  );
  Map<String, Object?> match(
    String query,
    List<DeviceContactRow> rows, [
    ContactInputSource source = ContactInputSource.asr,
  ]) => ContactNameMatcher(rows, dictionary).resolve([query], source).single;
  List<Map> candidates(Map value) =>
      (value['candidates'] as List? ?? []).cast<Map>();
  test(
    'typed traditional and case folding exact; no substring or homophone',
    () {
      final matcher = ContactNameMatcher([
        row('張三', '13800000000'),
        row('Alice', '13800000001'),
      ], dictionary);
      final results = matcher.resolve([
        ' 张三 ',
        'alice',
        '张',
        '章三',
      ], ContactInputSource.typed);
      expect(results.map((r) => r['status']), [
        'RESOLVED',
        'RESOLVED',
        'NOT_FOUND',
        'NOT_FOUND',
      ]);
      expect(results.first['phoneNumber'], '13800000000');
      expect(results.first['requestedName'], '张三');
      expect(results.first['inputSource'], 'typed');
      expect(results.first['contactId'], 'synthetic');
      expect(results.first['label'], '工作');
    },
  );
  test('unknown source is exact and request duplicates are removed stably', () {
    final results = ContactNameMatcher(
      [row('张三', '13800000000')],
      dictionary,
    ).resolve([' ', '张三', ' 张三 ', 'zhangsan'], ContactInputSource.unknown);
    expect(results, hasLength(2));
    expect(results.last['status'], 'NOT_FOUND');
  });
  test(
    'same normalized name-phone dedup but multiple numbers kept, no first selection',
    () {
      final result = match('张三', [
        row('张三', '13800000000'),
        row(' 張三 ', '+8613800000000'),
        row('张三', '13800000001'),
      ], ContactInputSource.typed);
      expect(result['status'], 'MULTIPLE_CANDIDATES');
      expect(result.containsKey('phoneNumber'), false);
      expect(candidates(result), hasLength(2));
    },
  );
  // Equivalent golden scenarios from v65 ContactPinyinSearchEngineTest.
  for (final query in ['zhang san', 'zhangsan', '章三']) {
    test('single pinyin $query always requires candidate confirmation', () {
      final result = match(query, [row('张三', '13800000000')]);
      expect(result['status'], 'MULTIPLE_CANDIDATES');
      expect(result['matchType'], 'pinyin_fallback');
      expect(candidates(result).single['displayName'], '张三');
    });
  }
  test('exact pronunciation sorts before fuzzy pronunciation', () {
    final result = match('zhang san', [
      row('臧三', '13800000001'),
      row('张三', '13800000000'),
    ]);
    expect(candidates(result).map((c) => c['displayName']), ['张三', '臧三']);
  });
  test('v65 final and initial fuzzy weights', () {
    expect(ContactPinyinSearch.score(['LIN'], ['LING']), 95);
    expect(ContactPinyinSearch.score(['ZANG'], ['ZHANG']), 90);
    expect(ContactPinyinSearch.score(['ZAN'], ['ZHANG']), closeTo(85.5, .0001));
    expect(ContactPinyinSearch.score(['HUANG'], ['WANG']), 80);
    expect(ContactPinyinSearch.variants('EN').containsKey('UN'), false);
    expect(ContactPinyinSearch.variants('CEN')['CUN'], .80);
    expect(ContactPinyinSearch.variants('CHEN').containsKey('TEN'), false);
    expect(ContactPinyinSearch.variants('CHANG')['TANG'], .75);
  });
  test(
    'last two syllables, wildcard and maximum four syllables follow v65',
    () {
      expect(
        ContactPinyinSearch.score(
          ['XIAO', 'MING'],
          ['OU', 'YANG', 'XIAO', 'MING'],
        ),
        80,
      );
      expect(ContactPinyinSearch.score(['?', 'SAN'], ['ZHANG', 'SAN']), 100);
      expect(
        ContactPinyinSearch.score(
          ['YI', 'ER', 'SAN', 'SI', 'WU'],
          ['YI', 'ER', 'SAN', 'SI', 'WU'],
        ),
        isNull,
      );
      expect(
        candidates(
          match('xiao ming', [row('欧阳小明', '13800000000')]),
        ).single['displayName'],
        '欧阳小明',
      );
    },
  );
  test('ASR exact adds homophones, while typed does not', () {
    final rows = [row('张三', '13800000000'), row('章三', '13800000001')];
    final result = match('张三', rows);
    expect(result['matchType'], 'name_exact_with_pinyin_candidates');
    expect(result['status'], 'MULTIPLE_CANDIDATES');
    expect(match('张三', rows, ContactInputSource.typed)['status'], 'RESOLVED');
  });
  test('ASR substring only if no exact match, invalid phone excluded', () {
    final result = match('销售', [row('销售小张', '13800000000'), row('销售', 'bad')]);
    expect(result['matchType'], 'name_like');
    expect(result['status'], 'RESOLVED');
    expect(result['displayName'], '销售小张');
  });
  test('zero results carry no invented candidates', () {
    final result = match('未知', [
      row('张三', '13800000000'),
    ], ContactInputSource.typed);
    expect(result['status'], 'NOT_FOUND');
    expect(result.containsKey('candidates'), false);
    expect(result.containsKey('phoneNumber'), false);
  });
}
