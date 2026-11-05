import 'package:flutter_test/flutter_test.dart';
import '../../support/translation_directory_fixture.dart';
import 'package:phone_agent/features/dialer/domain/dial_recent_call.dart';
import 'package:phone_agent/features/dialer/domain/system_dialer.dart';
import 'package:phone_agent/features/dialer/presentation/controller/dialer_controller.dart';
import 'package:phone_agent/features/dialer/presentation/widgets/dial_recent_list.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_setup_controller.dart';

DialRecentCall record(
  String id,
  int time, {
  DialRecentSource source = DialRecentSource.system,
  DialRecentKind kind = DialRecentKind.normal,
  String phone = '+12025550101',
  String name = '',
  String country = '',
}) => DialRecentCall(
  id: id,
  phone: phone,
  startedAtMillis: time,
  source: source,
  kind: kind,
  name: name,
  countryIso: country,
);

class NoCalls implements SystemDialer {
  int calls = 0;
  @override
  Future<SystemDialResult> open(String number) async {
    calls++;
    return SystemDialResult.opened;
  }
}

void main() {
  test(
    'merge excludes local normal/agent, retains source identities and times',
    () {
      final first = record('a', 30), duplicate = record('a', 99);
      final local = record(
        'a',
        40,
        source: DialRecentSource.app,
        kind: DialRecentKind.translation,
      );
      final merged = mergeDialRecentCalls(
        [first, duplicate, record('b', 30)],
        [
          local,
          record('no', 100, source: DialRecentSource.app),
          record(
            'agent',
            100,
            source: DialRecentSource.app,
            kind: DialRecentKind.agent,
          ),
        ],
      );
      expect(merged.map((v) => v.key), ['app:a', 'system:a', 'system:b']);
      expect(merged[1], same(first));
      expect(() => merged.clear(), throwsUnsupportedError);
    },
  );
  test('20 latest calls retained, same number never deduplicated', () {
    final rows = List.generate(25, (i) => record('$i', i));
    expect(mergeDialRecentCalls(rows, []).length, 20);
    expect(mergeDialRecentCalls(rows, []).last.id, '5');
    expect(mergeDialRecentCalls(rows, [], limit: 0), isEmpty);
    expect(mergeDialRecentCalls(rows, [], limit: -1), isEmpty);
  });
  test(
    'restore local country without losing explicit international prefix',
    () {
      expect(
        record(
          'a',
          1,
          source: DialRecentSource.app,
          phone: '2025550103',
          country: 'US',
        ).restorablePhone,
        '+12025550103',
      );
      for (final number in ['+12025550103', '0012025550103', '*123#', '']) {
        expect(
          record(
            'a',
            1,
            source: DialRecentSource.app,
            phone: number,
            country: 'US',
          ).restorablePhone,
          number,
        );
      }
      expect(
        record('a', 1, phone: '2025550103', country: 'US').restorablePhone,
        '2025550103',
      );
    },
  );
  test(
    'unknown numbers cannot select, unsupported country reports error without call',
    () {
      final port = NoCalls();
      final active = DialerController(port);
      addTearDown(active.dispose);
      active.digit('9');
      for (final number in ['', ' ', '-1', '-2']) {
        expect(active.restoreRecent(record('x', 1, phone: number)), isFalse);
        expect(active.state.input, '9');
      }
      expect(
        active.restoreRecent(record('x', 1, phone: '+442071234567')),
        isFalse,
      );
      expect(active.state.message, '暂不支持该号码国家或地区');
      expect(port.calls, 0);
    },
  );
  test(
    'selection restores local number and name only; does not start a call',
    () {
      final port = NoCalls();
      final active = DialerController(port);
      addTearDown(active.dispose);
      expect(
        active.restoreRecent(
          record(
            'x',
            1,
            source: DialRecentSource.app,
            phone: '2025550103',
            name: '合成',
            country: 'US',
          ),
        ),
        isTrue,
      );
      expect(active.state.input, '2025550103');
      expect(active.state.countryIso, 'US');
      expect(active.state.name, '合成');
      expect(port.calls, 0);
    },
  );
  test(
    'translation restore preserves mode and resets peer in ordinary mode',
    () {
      final setup = TranslationSetupController()
        ..directory(syntheticTranslationDirectory);
      addTearDown(setup.dispose);
      setup.language('fr', caller: false);
      setup.enable(false);
      setup.restoreHistory(countryIso: 'US', callerLanguage: 'ja');
      expect(setup.snapshot.enabled, isFalse);
      expect(setup.snapshot.normalCountry, 'US');
      expect(setup.snapshot.translationCountry, 'CN');
      expect(setup.snapshot.caller, 'ja');
      expect(setup.snapshot.peer, 'en');
      setup.restoreHistory(countryIso: 'XX', callerLanguage: 'invalid');
      expect(setup.snapshot.country, 'US');
      expect(setup.snapshot.caller, 'ja');
    },
  );
  test('display title, numbers and v65 calendar boundary', () {
    expect(dialRecentTitle(record('x', 1, name: '实时翻译 合成')), '合成');
    expect(dialRecentTitle(record('x', 1)), '+12025550101');
    expect(dialRecentNumber(record('x', 1)), '+1 202 555 0101');
    expect(dialRecentNumber(record('x', 1, phone: '-1')), '-1');
    final now = DateTime(2026, 9, 17, 14);
    expect(
      dialRecentTime(DateTime(2026, 9, 17, 9, 5).millisecondsSinceEpoch, now),
      '09:05',
    );
    expect(
      dialRecentTime(DateTime(2026, 9, 16).millisecondsSinceEpoch, now),
      '昨天',
    );
    expect(dialRecentTime(0, now), '');
    expect(
      dialRecentTime(
        DateTime(2025, 12, 31).millisecondsSinceEpoch,
        DateTime(2026, 1, 1),
      ),
      '12/31',
    );
  });
}
