import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/dialer/data/app_call_record_codec.dart';
import 'package:phone_agent/features/dialer/data/legacy_app_call_record_codec.dart';
import 'package:phone_agent/features/dialer/domain/app_call_record_repository.dart';
import 'package:phone_agent/features/dialer/domain/dial_recent_call.dart';

Map<String, Object?> legacyRecordFixture() => {
  'title': '实时翻译 合成姓名',
  'status': '已完成',
  'meta': '合成元数据',
  'success': true,
  'occurredAtMillis': 1746000000000,
  'phoneNumber': '2025550101',
  'callId': 'synthetic-call',
  'callKind': 'TRANSLATION',
  'contactDisplayName': '',
  'dialCountryIso': 'US',
  'callerLanguageCode': 'zh',
  'calleeLanguageCode': 'en',
  'transcript': [
    {'text': 'synthetic-private-transcript'},
  ],
  'resultText': 'synthetic-private-result',
};

void main() {
  List<DialRecentCall> parse(Map<String, Object?> row) =>
      LegacyAppCallRecordCodec.decode(jsonEncode([row]));
  test(
    'fixed metadata and title fallback are preserved, private text excluded',
    () {
      final rows = parse(legacyRecordFixture());
      final row = rows.single;
      expect(row.id, 'synthetic-call');
      expect(row.name, '合成姓名');
      expect(row.phone, '2025550101');
      expect(row.restorablePhone, '+12025550101');
      expect(row.startedAtMillis, 1746000000000);
      expect(row.kind, DialRecentKind.translation);
      expect(row.countryIso, 'US');
      expect(row.callerLanguage, 'zh');
      expect(row.peerLanguage, 'en');
      final encoded = AppCallRecordCodec.encode('scope', rows);
      expect(encoded, isNot(contains('synthetic-private')));
      expect(encoded, isNot(contains('success')));
      expect(() => rows.clear(), throwsUnsupportedError);
    },
  );
  test('explicit name wins and numeric title is not a contact name', () {
    expect(
      parse(
        legacyRecordFixture()..['contactDisplayName'] = ' 明确名称 ',
      ).single.name,
      '明确名称',
    );
    expect(
      parse(legacyRecordFixture()..['title'] = '翻译通话 202 555 0101').single.name,
      '',
    );
    expect(parse(legacyRecordFixture()..['title'] = '未知前缀 名称').single.name, '');
  });
  test('missing timestamp and ID use v65 fallback without invented time', () {
    final row = parse(
      legacyRecordFixture()
        ..remove('occurredAtMillis')
        ..remove('callId'),
    ).single;
    expect(row.startedAtMillis, 0);
    expect(row.id, '2025550101:0:TRANSLATION');
    expect(
      parse(
        legacyRecordFixture()..['occurredAtMillis'] = -1,
      ).single.startedAtMillis,
      0,
    );
  });
  test('missing and unknown kind remain agent, normal remains normal', () {
    for (final value in [null, '', 'FUTURE']) {
      expect(
        parse(legacyRecordFixture()..['callKind'] = value).single.kind,
        DialRecentKind.agent,
      );
    }
    expect(
      parse(legacyRecordFixture()..['callKind'] = 'NORMAL').single.kind,
      DialRecentKind.normal,
    );
  });
  test(
    'blank legacy required fields skipped, valid order and repeated calls retained',
    () {
      final rows = LegacyAppCallRecordCodec.decode(
        jsonEncode([
          legacyRecordFixture(),
          legacyRecordFixture()..['title'] = '',
          legacyRecordFixture()..['status'] = null,
          legacyRecordFixture()..['meta'] = ' ',
          legacyRecordFixture()..['callId'] = 'second',
        ]),
      );
      expect(rows.map((r) => r.id), ['synthetic-call', 'second']);
    },
  );
  test(
    'missing and legacy JSON null are empty; malformed JSON is explicit failure',
    () {
      for (final raw in [null, '', '  ', 'null', '[]']) {
        expect(LegacyAppCallRecordCodec.decode(raw), isEmpty);
      }
      for (final raw in [
        '{',
        '{}',
        '[null]',
        jsonEncode([legacyRecordFixture()..['occurredAtMillis'] = 'bad']),
      ]) {
        expect(
          () => LegacyAppCallRecordCodec.decode(raw),
          throwsA(isA<AppCallRecordFailure>()),
        );
      }
    },
  );
  test('oversized legacy source fails without partial import', () {
    for (final character in ['x', ' ']) {
      expect(
        () => LegacyAppCallRecordCodec.decode(
          character * (LegacyAppCallRecordCodec.maxBytes + 1),
        ),
        throwsA(isA<AppCallRecordFailure>()),
      );
    }
  });
}
