import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/contacts/data/lpinyin_contact_dictionary.dart';
import 'package:phone_agent/features/contacts/domain/contact_records.dart';
import 'package:phone_agent/features/contacts/domain/contact_name_matcher.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/tools/name_contact_lookup.dart';

void main() {
  late _Source source;
  late _Reply reply;
  late NameContactLookup lookup;
  setUp(() {
    source = _Source();
    reply = _Reply();
    lookup = NameContactLookup(source, reply, const LpinyinContactDictionary());
  });
  Future<AgentEvent?> run({
    ContactInputSource input = ContactInputSource.typed,
    List<String> names = const ['張三', '没有'],
    bool Function()? active,
  }) => lookup.run(
    sessionId: 's',
    toolCallId: 't',
    names: names,
    source: input,
    isCurrent: active ?? () => true,
  );
  test('typed source returns resolved and not found independently', () async {
    await run();
    expect(source.requested, true);
    expect(reply.results.map((r) => r['status']), ['RESOLVED', 'NOT_FOUND']);
    expect(reply.results.first['inputSource'], 'typed');
    expect(reply.results.first['requestedName'], '張三');
    expect(reply.results.first['displayName'], '张三');
  });
  for (final access in [
    ContactAccess.denied,
    ContactAccess.restricted,
    ContactAccess.unsupported,
  ]) {
    test(
      'access $access returns per-name failure, never fake NOT_FOUND',
      () async {
        source.access = access;
        await run();
        expect(reply.results, hasLength(2));
        for (final result in reply.results) {
          expect(
            result['status'],
            access == ContactAccess.unsupported
                ? 'UNAVAILABLE'
                : 'PERMISSION_DENIED',
          );
          expect(result.containsKey('candidates'), false);
        }
      },
    );
  }
  test(
    'read exception returns UNAVAILABLE; result POST exception is not retried',
    () async {
      source.fail = true;
      await run();
      expect(reply.results.first['status'], 'UNAVAILABLE');
      reply.fail = true;
      await expectLater(run(), throwsStateError);
      expect(reply.calls, 2);
    },
  );
  test('asr provenance activates pinyin, typed does not', () async {
    await run(names: ['zhangsan']);
    expect(reply.results.single['status'], 'NOT_FOUND');
    await run(names: ['zhangsan'], input: ContactInputSource.asr);
    expect(reply.results.single['status'], 'MULTIPLE_CANDIDATES');
    expect(reply.results.single['inputSource'], 'asr');
  });
  test(
    'exit while device request waits prevents any result submission',
    () async {
      source.gate = Completer<void>();
      var current = true;
      final pending = run(active: () => current);
      current = false;
      source.gate!.complete();
      expect(await pending, isNull);
      expect(reply.calls, 0);
    },
  );
  test(
    'limited scope keeps resolved and multiple, marks only missing',
    () async {
      source.access = ContactAccess.limited;
      var notices = 0;
      await lookup.run(
        sessionId: 's',
        toolCallId: 't',
        names: ['张三', '没有'],
        source: ContactInputSource.typed,
        isCurrent: () => true,
        onLimitedAccess: () => notices++,
      );
      expect(reply.results.map((r) => r['status']), [
        'RESOLVED',
        'PERMISSION_LIMITED',
      ]);
      expect(reply.results.every((r) => r['accessScope'] == 'limited'), isTrue);
      expect(notices, 1);
      await lookup.run(
        sessionId: 's',
        toolCallId: 't',
        names: ['zhangsan'],
        source: ContactInputSource.asr,
        isCurrent: () => true,
        onLimitedAccess: () => notices++,
      );
      expect(reply.results.single['status'], 'MULTIPLE_CANDIDATES');
      expect(reply.results.single['candidates'], hasLength(1));
      expect(notices, 1);
    },
  );
  test('limited notice closing owner prevents submission', () async {
    source.access = ContactAccess.limited;
    var current = true;
    final result = await lookup.run(
      sessionId: 's',
      toolCallId: 't',
      names: ['没有'],
      source: ContactInputSource.typed,
      isCurrent: () => current,
      onLimitedAccess: () => current = false,
    );
    expect(result, isNull);
    expect(reply.calls, 0);
  });
  test('invalid empty names never request device permission', () async {
    await expectLater(run(names: [' ']), throwsFormatException);
    expect(source.calls, 0);
  });
}

class _Source implements DeviceContactSource {
  ContactAccess access = ContactAccess.authorized;
  int calls = 0;
  bool fail = false, requested = false;
  Completer<void>? gate;
  @override
  Future<DeviceContactsSnapshot> load({bool requestPermission = false}) async {
    calls++;
    requested = requestPermission;
    if (gate != null) await gate!.future;
    if (fail) throw StateError('synthetic');
    return DeviceContactsSnapshot(access, const [
      DeviceContactRow(name: '张三', phone: '13800000000'),
    ]);
  }
}

class _Reply implements NameContactLookupContinuation {
  List<Map<String, Object?>> results = [];
  int calls = 0;
  bool fail = false;
  @override
  Future<AgentEvent> submitNames({
    required String sessionId,
    required String toolCallId,
    required List<Map<String, Object?>> results,
  }) async {
    this.results = results;
    calls++;
    if (fail) throw StateError('synthetic');
    return AgentEvent(
      AgentEventKind.finalResponse,
      sessionId: sessionId,
      text: '合成',
    );
  }
}
