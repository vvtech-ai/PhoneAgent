import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/context/agent_clock.dart';
import 'package:phone_agent/features/conversation/domain/context/agent_context_builder.dart';
import 'package:phone_agent/features/conversation/domain/tools/conversation_permission.dart';

class FakeClock implements AgentClockSource {
  int reads = 0;
  AgentClockSnapshot value = snapshot();
  Future<AgentClockSnapshot> Function()? pending;
  @override
  Future<AgentClockSnapshot> read() async {
    reads++;
    return pending == null ? value : await pending!();
  }
}

AgentClockSnapshot snapshot({
  int offset = 28800,
  String zone = 'Asia/Shanghai',
}) => AgentClockSnapshot(
  epochMillis: DateTime.utc(2026, 9, 18, 23, 59).millisecondsSinceEpoch,
  offsetSeconds: offset,
  timezone: zone,
);

class FakePermissions implements ConversationPermissionSource {
  final requests = <bool>[];
  PermissionGrant grant = PermissionGrant.granted;
  Future<PermissionGrant> Function(ConversationPermission)? handler;
  @override
  Future<PermissionGrant> resolve(
    ConversationPermission permission, {
    required bool request,
  }) async {
    requests.add(request);
    return handler == null ? grant : await handler!(permission);
  }
}

void main() {
  for (final grant in [PermissionGrant.denied, PermissionGrant.unavailable]) {
    test(
      'position is removed when final location permission is $grant',
      () async {
        final permissions = FakePermissions()
          ..handler = (p) async => p == ConversationPermission.location
              ? grant
              : PermissionGrant.granted;
        final builder = AgentContextBuilder(
          location: () async => {'lat': 1.0, 'lng': 2.0},
          clock: FakeClock(),
          permissions: permissions,
        );
        final context = await builder.prepare();
        expect(context.containsKey('lat'), false);
        expect(context.containsKey('lng'), false);
        expect((context['permissionStatus'] as Map)['contacts'], 'OK');
        expect(context['currentTime'], isNotNull);
      },
    );
  }
  for (final offset in [28800, -25200, 20700, -12600, 0]) {
    test('ISO offset $offset retains the instant and wall date', () {
      final clock = snapshot(offset: offset);
      final iso = clock.toContext()['isoDateTime'] as String;
      expect(DateTime.parse(iso).millisecondsSinceEpoch, clock.epochMillis);
      expect(iso.endsWith(AgentClockSnapshot.offsetText(offset)), isTrue);
      expect(iso.substring(0, 10), offset > 0 ? '2026-09-19' : '2026-09-18');
    });
  }
  test(
    'invalid zone and impossible offset fail rather than fabricate time',
    () {
      expect(() => snapshot(zone: 'invalid zone'), throwsFormatException);
      expect(() => snapshot(offset: 64801), throwsFormatException);
    },
  );
  test(
    'each turn refreshes time and permissions, preserves position',
    () async {
      final clock = FakeClock(), permissions = FakePermissions();
      final builder = AgentContextBuilder(
        location: () async => {'lat': 22.5},
        clock: clock,
        permissions: permissions,
      );
      final first = await builder.prepare();
      expect(first['lat'], 22.5);
      expect(first['permissionStatus'], {
        'microphone': 'OK',
        'contacts': 'OK',
        'location': 'OK',
        'document_picker': 'OK',
      });
      clock.value = snapshot(offset: -25200, zone: 'America/Los_Angeles');
      permissions.grant = PermissionGrant.denied;
      final second = await builder.prepare();
      expect((second['currentTime'] as Map)['timezone'], 'America/Los_Angeles');
      expect((second['permissionStatus'] as Map)['contacts'], 'NOT_GRANTED');
      expect(clock.reads, 2);
      expect(permissions.requests, List.filled(8, false));
    },
  );
  test('clock is sampled after location wait, not before midnight', () async {
    final location = Completer<Map<String, Object?>>(), clock = FakeClock();
    final builder = AgentContextBuilder(
      location: () => location.future,
      clock: clock,
      permissions: FakePermissions(),
    );
    final result = builder.prepare();
    expect(clock.reads, 0);
    clock.value = snapshot(zone: 'Asia/Kathmandu', offset: 20700);
    location.complete({});
    expect((await result)['currentTime'], clock.value.toContext());
  });
  test(
    'permission failure and time timeout do not block other fields',
    () async {
      final clock = FakeClock()
        ..pending = () => Completer<AgentClockSnapshot>().future;
      final permissions = FakePermissions()
        ..handler = (p) async {
          if (p == ConversationPermission.microphone) {
            throw StateError('synthetic');
          }
          if (p == ConversationPermission.contacts) {
            return Completer<PermissionGrant>().future;
          }
          if (p == ConversationPermission.location) {
            return PermissionGrant.unavailable;
          }
          return PermissionGrant.granted;
        };
      final fallback = snapshot(zone: '+08:00');
      final builder = AgentContextBuilder(
        location: () async => throw StateError('synthetic'),
        clock: clock,
        permissions: permissions,
        fallbackClock: () => fallback,
        snapshotTimeout: const Duration(milliseconds: 10),
      );
      final result = await builder.prepare();
      expect(result['currentTime'], fallback.toContext());
      expect(result['permissionStatus'], {
        'microphone': 'UNAVAILABLE',
        'contacts': 'UNAVAILABLE',
        'location': 'UNAVAILABLE',
        'document_picker': 'OK',
      });
      expect(result.containsKey('lat'), isFalse);
    },
  );
  test(
    'closing during location prevents permission reads and old output',
    () async {
      final location = Completer<Map<String, Object?>>(), clock = FakeClock();
      final permissions = FakePermissions();
      final builder = AgentContextBuilder(
        location: () => location.future,
        clock: clock,
        permissions: permissions,
      );
      final result = builder.prepare();
      builder.close();
      location.complete({'lat': 22.5});
      expect(await result, isEmpty);
      expect(await builder.prepare(), isEmpty);
      expect(clock.reads, 0);
      expect(permissions.requests, isEmpty);
    },
  );
  test('closing during permission wait discards snapshots', () async {
    final waiting = Completer<PermissionGrant>();
    final builder = AgentContextBuilder(
      location: () async => {},
      clock: FakeClock(),
      permissions: FakePermissions()..handler = (_) => waiting.future,
    );
    final result = builder.prepare();
    await Future<void>.delayed(Duration.zero);
    builder.close();
    waiting.complete(PermissionGrant.granted);
    expect(await result, isEmpty);
  });
}
