import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/dialer/domain/system_dialer.dart';
import 'package:phone_agent/features/dialer/domain/dial_recent_call.dart';
import 'package:phone_agent/features/translation/domain/translation_directory.dart';
import 'package:phone_agent/features/dialer/presentation/controller/dialer_controller.dart';

class _Port implements SystemDialer {
  final numbers = <String>[];
  final result = Completer<SystemDialResult>();
  @override
  Future<SystemDialResult> open(String number) {
    numbers.add(number);
    return result.future;
  }
}

void main() {
  test(
    'notice is consumed only while it still matches the displayed event',
    () async {
      final c = DialerController(_Port(), onUnlockDeveloper: () {});
      for (final digit in '20142014*#'.split('')) {
        c.digit(digit);
      }
      await c.dial();
      expect(c.state.message, '已进入开发者模式');
      c.consumeMessage('older event');
      expect(c.state.message, '已进入开发者模式');
      c.consumeMessage('已进入开发者模式');
      expect(c.state.message, isEmpty);
      c.dispose();
      c.consumeMessage('已进入开发者模式');
    },
  );
  test(
    'directory contact and recent preparation retain configured country',
    () {
      const directory = TranslationDirectory(
        version: 1,
        countries: [
          TranslationDirectoryCountry('GB', '+44', '英国', 'en', [], '', ''),
        ],
        models: [],
        languages: [],
      );
      final c = DialerController(_Port());
      addTearDown(c.dispose);
      c.prepare('+44 20 1234 5678', name: '合成联系人', directory: directory);
      expect(c.state.input, '2012345678');
      expect(c.state.name, '合成联系人');
      expect(c.state.country.code, '+44');
      expect(c.state.country.name, '英国');
      c.clear();
      c.country('CN');
      expect(
        c.restoreRecent(
          const DialRecentCall(
            id: 'synthetic',
            phone: '2012345678',
            countryIso: 'GB',
            startedAtMillis: 1,
            source: DialRecentSource.app,
            kind: DialRecentKind.translation,
          ),
          directory: directory,
        ),
        isTrue,
      );
      expect(c.state.country.code, '+44');
      expect(c.state.input, '2012345678');
    },
  );
  test(
    'handoff is recorded once with captured identity even after sheet disposal',
    () async {
      final port = _Port();
      final records = <List<String>>[];
      final c = DialerController(
        port,
        onOpened: (phone, name, iso) async => records.add([phone, name, iso]),
      );
      c.prepare('+12025550101', name: '合成姓名');
      final pending = c.dial();
      await c.dial();
      c.dispose();
      port.result.complete(SystemDialResult.opened);
      await pending;
      expect(records, [
        ['+12025550101', '合成姓名', 'US'],
      ]);
      expect(port.numbers.length, 1);
    },
  );
  test(
    'storage failure does not retry or misreport successful platform handoff',
    () async {
      final port = _Port();
      final c = DialerController(
        port,
        onOpened: (_, __, ___) async => throw StateError('synthetic'),
      );
      addTearDown(c.dispose);
      c.prepare('10086');
      port.result.complete(SystemDialResult.opened);
      await c.dial();
      expect(c.state.message, contains('请勿重复拨号'));
      expect(port.numbers.length, 1);
      expect(c.state.busy, isFalse);
    },
  );
  test('preview and rejected handoff never write real records', () async {
    var writes = 0;
    for (final preview in [false, true]) {
      for (final result in SystemDialResult.values) {
        if (!preview && result == SystemDialResult.opened) continue;
        final port = _Port()..result.complete(result);
        final c = DialerController(
          port,
          preview: preview,
          onOpened: (_, __, ___) async {
            writes++;
          },
        );
        c.prepare('10086');
        await c.dial();
        c.dispose();
      }
    }
    expect(writes, 0);
  });
  test('input limit, delete, clear and contact name ownership', () {
    final c = DialerController(_Port());
    addTearDown(c.dispose);
    c.prepare('+1 2025550123', name: '合成联系人');
    expect(c.state.countryIso, 'US');
    expect(c.state.name, '合成联系人');
    c.digit('1');
    expect(c.state.name, isEmpty);
    c.clear();
    for (var i = 0; i < 15; i++) {
      c.digit('1');
    }
    expect(c.state.input.length, 14);
    expect(c.state.message, contains('14'));
    c.digit('#');
    expect(c.state.input.endsWith('#'), isTrue);
    c.delete();
    expect(c.state.input.length, 14);
    c.country('CA');
    expect(c.state.countryIso, 'US');
    c.clear();
    expect(c.state.input, isEmpty);
  });
  test(
    'invalid prefill clears stale number; developer code cannot dial',
    () async {
      final port = _Port();
      final controller = DialerController(port);
      addTearDown(controller.dispose);
      controller.prepare('10086');
      controller.prepare('+44 2012345678');
      expect(controller.state.input, isEmpty);
      await controller.dial();
      for (final key in '20142014*#'.split('')) {
        controller.digit(key);
      }
      await controller.dial();
      expect(port.numbers, isEmpty);
      expect(controller.state.message, contains('开发者'));
    },
  );
  test(
    'single flight, busy edits blocked and no connected success claim',
    () async {
      final port = _Port();
      final c = DialerController(port);
      addTearDown(c.dispose);
      c.prepare('13800138000');
      final pending = c.dial();
      await c.dial();
      c.clear();
      c.delete();
      c.country('US');
      c.digit('2');
      expect(c.state.input, '13800138000');
      expect(c.state.countryIso, 'CN');
      expect(port.numbers, ['+8613800138000']);
      port.result.complete(SystemDialResult.opened);
      await pending;
      expect(c.state.busy, isFalse);
      expect(c.state.message, '已交给系统电话，请在系统界面确认');
    },
  );
  for (final result in SystemDialResult.values) {
    test(
      'result $result clears busy and preview does not claim real call',
      () async {
        final port = _Port();
        final c = DialerController(port, preview: true);
        addTearDown(c.dispose);
        c.prepare('10086');
        port.result.complete(result);
        await c.dial();
        expect(c.state.busy, isFalse);
        expect(c.state.message, isNotEmpty);
        if (result == SystemDialResult.opened) {
          expect(c.state.message, contains('MOCK'));
        }
      },
    );
  }
  test(
    'exception becomes failure and result after dispose is ignored',
    () async {
      final port = _Port();
      final c = DialerController(port);
      c.prepare('10086');
      final pending = c.dial();
      port.result.completeError(StateError('no phone app'));
      await pending;
      expect(c.state.message, contains('无法打开'));
      c.dispose();
      final latePort = _Port();
      final lateController = DialerController(latePort)..prepare('10086');
      final lateResult = lateController.dial();
      lateController.dispose();
      latePort.result.complete(SystemDialResult.opened);
      await lateResult;
    },
  );
}
