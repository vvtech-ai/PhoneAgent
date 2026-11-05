import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/contacts/domain/contact_records.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/tools/phone_contact_lookup.dart';

void main() {
  test('v65 normalized suffix match sends name and system label only', () {
    expect(
      PhoneContactLookup.match('+8613800000000', const [
        DeviceContactRow(name: ' 合成 ', phone: '138 0000 0000', label: ' 工作 '),
      ]),
      {'found': true, 'source': 'device', 'displayName': '合成', 'note': '工作'},
    );
    expect(
      PhoneContactLookup.match('5550101', const [
        DeviceContactRow(name: '美国', phone: '+1 202 555 0101'),
      ])['found'],
      true,
    );
  });
  test(
    'blank first matching name stays not found, never unknown placeholder',
    () {
      expect(
        PhoneContactLookup.match('13800000000', const [
          DeviceContactRow(name: '', phone: '13800000000'),
          DeviceContactRow(name: '后一个', phone: '13800000000'),
        ]),
        {'found': false},
      );
      expect(PhoneContactLookup.match('abc', const []), {'found': false});
      expect(
        PhoneContactLookup.match('13800000009', const [
          DeviceContactRow(name: '合成', phone: '13800000000'),
        ]),
        {'found': false},
      );
    },
  );
  test(
    'limited phone scope marks missing and preserves matched fields',
    () async {
      final source = _Source()..access = ContactAccess.limited;
      final reply = _Reply();
      var notices = 0;
      final lookup = PhoneContactLookup(source, reply);
      for (final phone in ['13800000000', '13800000009']) {
        await lookup.run(
          sessionId: 's',
          toolCallId: 't',
          phone: phone,
          isCurrent: () => true,
          onLimitedAccess: () => notices++,
        );
        expect(reply.result!['accessScope'], 'limited');
        expect(reply.result!['found'], phone == '13800000000');
      }
      expect(reply.result!['reason'], 'PERMISSION_LIMITED');
      expect(notices, 1);
    },
  );
  for (final access in ContactAccess.values) {
    test(
      'access $access has explicit result and never uploads all rows',
      () async {
        final source = _Source()..access = access;
        final reply = _Reply();
        await PhoneContactLookup(source, reply).run(
          sessionId: 's',
          toolCallId: 't',
          phone: '13800000000',
          isCurrent: () => true,
        );
        expect(source.requested, true);
        expect(
          reply.result!['found'],
          access == ContactAccess.authorized || access == ContactAccess.limited,
        );
        if (reply.result!['found'] == false) {
          expect(
            reply.result!['reason'],
            access == ContactAccess.unsupported
                ? 'DEVICE_LOOKUP_FAILED'
                : 'PERMISSION_DENIED',
          );
        }
        expect(reply.result!.containsKey('rows'), false);
      },
    );
  }
  test(
    'read failure is returned but HTTP failure propagates without retry',
    () async {
      final source = _Source()..fail = true;
      final reply = _Reply();
      final lookup = PhoneContactLookup(source, reply);
      await lookup.run(
        sessionId: 's',
        toolCallId: 't',
        phone: '1',
        isCurrent: () => true,
      );
      expect(reply.result, {'found': false, 'reason': 'DEVICE_LOOKUP_FAILED'});
      reply.fail = true;
      await expectLater(
        lookup.run(
          sessionId: 's',
          toolCallId: 't2',
          phone: '1',
          isCurrent: () => true,
        ),
        throwsStateError,
      );
      expect(reply.calls, 2);
    },
  );
  test('closed before and during device read never submits', () async {
    final source = _Source()..gate = Completer<void>();
    final reply = _Reply();
    final lookup = PhoneContactLookup(source, reply);
    await lookup.run(
      sessionId: 's',
      toolCallId: 't',
      phone: '1',
      isCurrent: () => false,
    );
    expect(source.calls, 0);
    var active = true;
    final pending = lookup.run(
      sessionId: 's',
      toolCallId: 't',
      phone: '1',
      isCurrent: () => active,
    );
    active = false;
    source.gate!.complete();
    expect(await pending, isNull);
    expect(reply.calls, 0);
  });
  test('missing context never requests permission', () async {
    final source = _Source();
    await expectLater(
      PhoneContactLookup(
        source,
        _Reply(),
      ).run(sessionId: 's', toolCallId: '', phone: '1', isCurrent: () => true),
      throwsFormatException,
    );
    expect(source.calls, 0);
  });
}

class _Source implements DeviceContactSource {
  ContactAccess access = ContactAccess.authorized;
  bool requested = false, fail = false;
  int calls = 0;
  Completer<void>? gate;
  @override
  Future<DeviceContactsSnapshot> load({bool requestPermission = false}) async {
    calls++;
    requested = requestPermission;
    if (gate != null) await gate!.future;
    if (fail) throw StateError('synthetic');
    return DeviceContactsSnapshot(access, const [
      DeviceContactRow(name: '合成', phone: '13800000000'),
    ]);
  }
}

class _Reply implements ContactLookupContinuation {
  Map<String, Object?>? result;
  int calls = 0;
  bool fail = false;
  @override
  Future<AgentEvent> submit({
    required String sessionId,
    required String toolCallId,
    required Map<String, Object?> result,
  }) async {
    calls++;
    this.result = result;
    if (fail) throw StateError('synthetic');
    return AgentEvent(
      AgentEventKind.finalResponse,
      sessionId: sessionId,
      text: '已返回',
    );
  }
}
