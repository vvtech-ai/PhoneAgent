import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/context/conversation_permission_resume.dart';
import 'package:phone_agent/features/conversation/domain/context/task_location_permission.dart';
import 'package:phone_agent/features/conversation/domain/tools/conversation_permission.dart';

AgentCommand _turn(String id) => AgentCommand(
  sessionId: 'task',
  userId: 'account',
  commandId: id,
  idempotencyKey: id,
  traceId: id,
  message: '附近餐厅',
);

class _DelayedPermission implements ConversationPermissionSource {
  _DelayedPermission({required this.delayRequest});
  final bool delayRequest;
  final old = Completer<PermissionGrant>();
  Completer<PermissionGrant>? nextRequest;
  final requests = <bool>[];
  bool _delayed = false;
  @override
  Future<PermissionGrant> resolve(
    ConversationPermission permission, {
    required bool request,
  }) async {
    requests.add(request);
    if (!_delayed && request == delayRequest) {
      _delayed = true;
      return old.future;
    }
    return request
        ? nextRequest?.future ?? PermissionGrant.granted
        : PermissionGrant.denied;
  }
}

void main() {
  test('old permission token cannot abandon a later ordinary turn', () async {
    var abandoned = 0;
    final resume = ConversationPermissionResume(() => ++abandoned);
    final pending = Completer<int>();
    final old = resume.run((_) => pending.future, () => true);
    resume.background();
    expect(abandoned, 1);
    expect(pending.isCompleted, isFalse);
    resume.resume();
    resume.background();
    expect(abandoned, 1, reason: 'ordinary turn has no live permission owner');
    pending.complete(1);
    expect(await old, isNull);
  });
  for (final request in [false, true]) {
    test(
      'backgrounded pending ${request ? 'request' : 'check'} cannot block new intent',
      () async {
        final source = _DelayedPermission(delayRequest: request);
        final gate = TaskLocationPermission(source);
        final resume = ConversationPermissionResume(() {});
        gate.bindResume('task', resume, () {});
        final old = gate.prepare(_turn('old'), () => true);
        await Future<void>.delayed(Duration.zero);
        expect(source.requests, request ? [false, true] : [false]);
        resume.background();
        expect(gate.isPending('task'), isFalse);
        resume.resume();
        var completed = false;
        final fresh = gate
            .prepare(_turn('fresh'), () => true)
            .then((_) => completed = true);
        await Future<void>.delayed(Duration.zero);
        expect(
          completed,
          isTrue,
          reason: 'new owner must not await the obsolete native Future',
        );
        expect(source.old.isCompleted, isFalse);
        expect(
          source.requests,
          request ? [false, true, false, true] : [false, false, true],
        );
        source.old.complete(PermissionGrant.denied);
        await Future.wait([old, fresh]);
        final before = source.requests.length;
        await gate
            .forSession('task')
            .resolve(ConversationPermission.location, request: true);
        expect(
          source.requests.length,
          before + 1,
          reason: 'old denial must not poison fresh owner',
        );
      },
    );
  }

  test('old completion cannot remove a newer pending request', () async {
    final source = _DelayedPermission(delayRequest: true);
    final gate = TaskLocationPermission(source);
    final resume = ConversationPermissionResume(() {});
    gate.bindResume('task', resume, () {});
    final old = gate.prepare(_turn('old'), () => true);
    await Future<void>.delayed(Duration.zero);
    resume.background();
    resume.resume();
    source.nextRequest = Completer<PermissionGrant>();
    final fresh = gate.prepare(_turn('fresh'), () => true);
    await Future<void>.delayed(Duration.zero);
    source.old.complete(PermissionGrant.denied);
    await old;
    expect(gate.isPending('task'), isTrue);
    source.nextRequest!.complete(PermissionGrant.granted);
    await fresh;
    expect(gate.isPending('task'), isFalse);
  });
}
