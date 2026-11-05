import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/agent_context_providers.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/context/task_location_permission.dart';
import 'package:phone_agent/features/conversation/domain/tools/conversation_permission.dart';

class _Permissions implements ConversationPermissionSource {
  final requests = <bool>[];
  PermissionGrant grant = PermissionGrant.denied;
  Completer<PermissionGrant>? pending;
  @override
  Future<PermissionGrant> resolve(
    ConversationPermission permission, {
    required bool request,
  }) async {
    expect(permission, ConversationPermission.location);
    requests.add(request);
    return pending?.future ?? (request ? grant : PermissionGrant.denied);
  }
}

AgentCommand _turn({
  String id = 'turn',
  String? skill,
  String? text = '海底捞',
  String? action,
  SelectedContactContext? contact,
}) => AgentCommand(
  sessionId: 'task',
  userId: 'account',
  commandId: id,
  idempotencyKey: id,
  traceId: 'trace',
  initialSkillId: skill,
  message: text,
  actionId: action,
  selectedContact: contact,
);

void main() {
  test(
    'negative location phrases do not reset denial; affirmative command can retry',
    () async {
      final source = _Permissions();
      final gate = TaskLocationPermission(source);
      await gate.prepare(_turn(skill: 'restaurant_booking'), () => true);
      for (final text in ['不要再开启定位', '不授权定位，按北京地址订', '不用定位', '别申请定位']) {
        await gate.prepare(_turn(id: text, text: text), () => true);
      }
      expect(source.requests.where((request) => request), hasLength(1));
      await gate.prepare(_turn(id: 'retry', text: '请帮我开启定位权限'), () => true);
      expect(source.requests.where((request) => request), hasLength(2));
    },
  );
  test(
    'task denial survives route listeners and resets on account replacement',
    () async {
      final epoch = StateProvider<int?>((_) => 1);
      final source = _Permissions();
      final container = ProviderContainer(
        overrides: [
          loginEpochProvider.overrideWith((ref) => ref.watch(epoch)),
          conversationPermissionSourceProvider.overrideWithValue(source),
        ],
      );
      addTearDown(container.dispose);
      final listener = container.listen(
        taskLocationPermissionProvider,
        (_, _) {},
      );
      final gate = listener.read();
      await gate.prepare(_turn(text: '附近餐厅'), () => true);
      listener.close();
      await Future<void>.delayed(Duration.zero);
      expect(
        identical(container.read(taskLocationPermissionProvider), gate),
        isTrue,
      );
      await container
          .read(taskLocationPermissionProvider)
          .prepare(_turn(text: '附近餐厅'), () => true);
      expect(source.requests.where((request) => request), hasLength(1));
      container.read(epoch.notifier).state = 2;
      final replacement = container.read(taskLocationPermissionProvider);
      expect(identical(replacement, gate), isFalse);
      await replacement.prepare(_turn(text: '附近餐厅'), () => true);
      expect(source.requests.where((request) => request), hasLength(2));
    },
  );
  test(
    'preflight denial prevents a later permission tool from prompting again',
    () async {
      final source = _Permissions();
      final gate = TaskLocationPermission(source);
      await gate.prepare(_turn(skill: 'restaurant_booking'), () => true);
      final result =
          await ConversationPermissionCoordinator(
            gate.forSession('task'),
          ).resolve(
            const AgentEvent(
              AgentEventKind.signal,
              sessionId: 'task',
              payload: {
                'pendingToolCallId': 'tool-location',
                'permissionKey': 'location',
              },
            ),
            isCurrent: () => true,
          );
      expect(source.requests.where((request) => request), hasLength(1));
      expect(result!.payload['status'], 'DENIED');
    },
  );
  test('concurrent turns share one permission request and finish', () async {
    final source = _Permissions()..pending = Completer<PermissionGrant>();
    final gate = TaskLocationPermission(source);
    final first = gate.prepare(_turn(text: '附近餐厅'), () => true);
    final second = gate.prepare(_turn(text: '附近餐厅'), () => true);
    source.pending!.complete(PermissionGrant.denied);
    await Future.wait([first, second]);
    expect(source.requests, [false, true]);
  });
  test(
    'first submitted restaurant task requests permission without another user turn',
    () async {
      final source = _Permissions()..grant = PermissionGrant.granted;
      await TaskLocationPermission(
        source,
      ).prepare(_turn(skill: 'restaurant_booking'), () => true);
      expect(source.requests, [false, true]);
    },
  );
  test(
    'new nearby intent retries after denial while repeated command does not',
    () async {
      final source = _Permissions();
      final gate = TaskLocationPermission(source);
      await gate.prepare(_turn(skill: 'restaurant_booking'), () => true);
      await gate.prepare(_turn(id: 'next', text: '附近的海底捞'), () => true);
      await gate.prepare(_turn(id: 'next', text: '附近的海底捞'), () => true);
      expect(source.requests.where((request) => request), hasLength(2));
    },
  );
  test(
    'colloquial explicit relocation retries but ordinary followup does not',
    () async {
      final source = _Permissions();
      final gate = TaskLocationPermission(source);
      await gate.prepare(_turn(skill: 'restaurant_booking'), () => true);
      await gate.prepare(_turn(id: 'address', text: '按北京地址订'), () => true);
      expect(source.requests.where((request) => request), hasLength(1));
      await gate.prepare(_turn(id: 'relocate', text: '你重新获取定位呀'), () => true);
      expect(source.requests.where((request) => request), hasLength(2));
    },
  );
  test('already authorized does not request again', () async {
    final source = _Granted();
    await TaskLocationPermission(
      source,
    ).prepare(_turn(text: '附近的餐厅'), () => true);
    expect(source.requests, [false]);
  });
  test(
    'opening, action continuation and fixed contact do not request location',
    () async {
      final source = _Permissions();
      final gate = TaskLocationPermission(source);
      await gate.prepare(
        _turn(skill: 'restaurant_booking', text: ''),
        () => true,
      );
      await gate.prepare(
        _turn(text: '附近', action: 'permission_result'),
        () => true,
      );
      await gate.prepare(
        _turn(
          skill: 'restaurant_booking',
          contact: const SelectedContactContext(name: '餐厅', phone: '10086'),
        ),
        () => true,
      );
      await gate.prepare(_turn(text: '通知大家开会'), () => true);
      expect(source.requests, isEmpty);
    },
  );
  test(
    'account or request cancellation while checking never requests permission',
    () async {
      final source = _Permissions()..pending = Completer<PermissionGrant>();
      var current = true;
      final pending = TaskLocationPermission(
        source,
      ).prepare(_turn(text: '附近餐厅'), () => current);
      current = false;
      source.pending!.complete(PermissionGrant.denied);
      await pending;
      expect(source.requests, [false]);
    },
  );
}

class _Granted extends _Permissions {
  @override
  Future<PermissionGrant> resolve(
    ConversationPermission permission, {
    required bool request,
  }) async {
    requests.add(request);
    return PermissionGrant.granted;
  }
}
