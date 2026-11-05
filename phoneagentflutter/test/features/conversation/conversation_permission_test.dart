import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/tools/conversation_permission.dart';

void main() {
  test('permanent denial during system prompt requires settings', () async {
    final source = PermissionFake(request: PermissionGrant.blocked);
    final result = await ConversationPermissionCoordinator(
      source,
    ).resolve(signal(key: 'location', android: null), isCurrent: () => true);
    expect(result!.payload['status'], 'SETTINGS_REQUIRED');
    expect(result.payload['granted'], isFalse);
    expect(source.requests, [false, true]);
  });
  test('already blocked does not request a system prompt', () async {
    final source = PermissionFake(check: PermissionGrant.blocked);
    final result = await ConversationPermissionCoordinator(
      source,
    ).resolve(signal(), isCurrent: () => true);
    expect(result!.payload['status'], 'SETTINGS_REQUIRED');
    expect(source.requests, [false]);
  });
  test(
    'all supported keys parse; arbitrary native identifiers are rejected',
    () {
      for (final key in [
        'microphone',
        'contacts',
        'location',
        'document_picker',
      ]) {
        expect(
          ConversationPermissionRequest.parse({'permissionKey': key}).key,
          key,
        );
      }
      for (final input in [
        {'permissionKey': 'call_phone'},
        {
          'permissionKey': 'contacts',
          'androidPermission': 'android.permission.CALL_PHONE',
        },
        {'permissionKey': 'microphone', 'androidPermission': true},
        {
          'permissionKey': 'document_picker',
          'androidPermission': 'android.permission.READ_CONTACTS',
        },
      ]) {
        expect(
          () => ConversationPermissionRequest.parse(input),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'document picker is available without invoking system permission',
    () async {
      final source = PermissionFake();
      final result = await ConversationPermissionCoordinator(source).resolve(
        signal(key: 'document_picker', android: null),
        isCurrent: () => true,
      );
      expect(source.requests, isEmpty);
      expect(result!.payload['status'], 'OK');
    },
  );
  test('already authorized checks once, no request prompt', () async {
    final source = PermissionFake(check: PermissionGrant.granted);
    final result = await ConversationPermissionCoordinator(
      source,
    ).resolve(signal(), isCurrent: () => true);
    expect(source.requests, [false]);
    expect(result!.payload['granted'], true);
  });
  for (final granted in [true, false]) {
    test(
      'system response $granted returns exact action without user echo',
      () async {
        final source = PermissionFake(
          request: granted ? PermissionGrant.granted : PermissionGrant.denied,
        );
        final result = await ConversationPermissionCoordinator(
          source,
        ).resolve(signal(), isCurrent: () => true);
        expect(source.requests, [false, true]);
        final command = result!.command('s', 'u', 'c', 't', {
          'ocrAttachments': [],
        });
        final wire = command.toJson();
        expect(wire['actionId'], 'permission_result');
        expect(
          wire['actionPayload'],
          containsPair('status', granted ? 'OK' : 'DENIED'),
        );
        expect(wire['channel'], 'voice');
        expect(wire['sessionId'], 's');
        expect(wire['idempotencyKey'], 'c');
        expect(wire['userContext'], {'ocrAttachments': []});
        expect(wire.containsKey('message'), false);
      },
    );
  }
  test(
    'iOS location permission key without Android field requests authorization',
    () async {
      final source = PermissionFake();
      final result = await ConversationPermissionCoordinator(
        source,
      ).resolve(signal(key: 'location', android: null), isCurrent: () => true);
      expect(source.requests, [false, true]);
      expect(result!.payload['status'], 'OK');
      expect(result.payload.containsKey('androidPermission'), false);
    },
  );
  test(
    'unavailable platform does not attempt a prompt or fake denial',
    () async {
      final source = PermissionFake(check: PermissionGrant.unavailable);
      final result = await ConversationPermissionCoordinator(
        source,
      ).resolve(signal(), isCurrent: () => true);
      expect(source.requests, [false]);
      expect(result!.payload['status'], 'SETTINGS_REQUIRED');
    },
  );
  test(
    'repeated tool is resolved once; missing identity has no side effect',
    () async {
      final source = PermissionFake();
      final coordinator = ConversationPermissionCoordinator(source);
      await coordinator.resolve(signal(), isCurrent: () => true);
      expect(
        await coordinator.resolve(signal(), isCurrent: () => true),
        isNull,
      );
      expect(source.requests, [false, true]);
      await expectLater(
        coordinator.resolve(signal(tool: ''), isCurrent: () => true),
        throwsFormatException,
      );
      expect(source.requests, [false, true]);
    },
  );
  test(
    'closing while checking prevents requesting and returning result',
    () async {
      final pending = Completer<PermissionGrant>();
      final source = PermissionFake()..pendingCheck = pending.future;
      var current = true;
      final result = ConversationPermissionCoordinator(
        source,
      ).resolve(signal(), isCurrent: () => current);
      current = false;
      pending.complete(PermissionGrant.denied);
      expect(await result, isNull);
      expect(source.requests, [false]);
    },
  );
  test('closing while prompting discards result', () async {
    final pending = Completer<PermissionGrant>();
    final source = PermissionFake()..pendingRequest = pending.future;
    var current = true;
    final result = ConversationPermissionCoordinator(
      source,
    ).resolve(signal(), isCurrent: () => current);
    await Future<void>.delayed(Duration.zero);
    current = false;
    pending.complete(PermissionGrant.granted);
    expect(await result, isNull);
  });
  test('system exception is not silently turned into user denial', () async {
    final source = PermissionFake()..fail = true;
    await expectLater(
      ConversationPermissionCoordinator(
        source,
      ).resolve(signal(), isCurrent: () => true),
      throwsStateError,
    );
  });
}

AgentEvent signal({
  String key = 'contacts',
  String? android = 'android.permission.READ_CONTACTS',
  String tool = 'tool',
}) => AgentEvent(
  AgentEventKind.signal,
  sessionId: 's',
  payload: {
    'type': 'REQUEST_PERMISSION',
    'pendingToolCallId': tool,
    'permissionRequest': {
      'permissionKey': key,
      if (android != null) 'androidPermission': android,
    },
  },
);

class PermissionFake implements ConversationPermissionSource {
  PermissionFake({
    this.check = PermissionGrant.denied,
    this.request = PermissionGrant.granted,
  });
  final PermissionGrant check, request;
  final requests = <bool>[];
  Future<PermissionGrant>? pendingCheck, pendingRequest;
  bool fail = false;
  @override
  Future<PermissionGrant> resolve(
    ConversationPermission permission, {
    required bool request,
  }) async {
    requests.add(request);
    if (fail) throw StateError('synthetic');
    return request ? (pendingRequest ?? this.request) : (pendingCheck ?? check);
  }
}
