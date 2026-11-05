import '../tools/conversation_permission.dart';
import 'agent_clock.dart';

/// Fresh per turn, independent of UI. The owner is one login generation.
class AgentContextBuilder {
  AgentContextBuilder({
    required this.location,
    required this.clock,
    required this.permissions,
    this.memoryContext,
    AgentClockSnapshot Function()? fallbackClock,
    this.snapshotTimeout = const Duration(seconds: 2),
  }) : _fallbackClock = fallbackClock ?? AgentClockSnapshot.localNow;
  final Future<Map<String, Object?>> Function() location;
  final AgentClockSource clock;
  final ConversationPermissionSource permissions;
  final Future<Map<String, Object?>> Function()? memoryContext;
  final AgentClockSnapshot Function() _fallbackClock;
  final Duration snapshotTimeout;
  bool _closed = false;

  Future<Map<String, Object?>> prepare() async {
    if (_closed) return const {};
    Map<String, Object?> position = const {};
    try {
      position = await location();
    } catch (_) {}
    if (_closed) return const {};
    // Capture clock after location waiting, so crossing midnight isn't stale.
    final snapshots = await Future.wait([
      _time(),
      _memory(),
      for (final permission in ConversationPermission.values)
        _permission(permission),
    ]);
    if (_closed) return const {};
    final permissionStatus = {for (final item in snapshots.skip(2)) ...item};
    return {
      if (permissionStatus['location'] == 'OK') ...position,
      ...snapshots.first,
      ...snapshots[1],
      'permissionStatus': permissionStatus,
    };
  }

  Future<Map<String, Object?>> _memory() async {
    try {
      return await memoryContext?.call().timeout(snapshotTimeout) ?? const {};
    } catch (_) {
      return const {};
    }
  }

  Future<Map<String, Object?>> _time() async {
    AgentClockSnapshot value;
    try {
      value = await clock.read().timeout(snapshotTimeout);
    } catch (_) {
      value = _fallbackClock();
    }
    return {'currentTime': value.toContext()};
  }

  Future<Map<String, Object?>> _permission(
    ConversationPermission permission,
  ) async {
    final key = permission == ConversationPermission.documentPicker
        ? 'document_picker'
        : permission.name;
    try {
      final grant = await permissions
          .resolve(permission, request: false)
          .timeout(snapshotTimeout);
      return {
        key: switch (grant) {
          PermissionGrant.granted => 'OK',
          PermissionGrant.denied || PermissionGrant.blocked => 'NOT_GRANTED',
          PermissionGrant.unavailable => 'UNAVAILABLE',
        },
      };
    } catch (_) {
      return {key: 'UNAVAILABLE'};
    }
  }

  void close() => _closed = true;
}
