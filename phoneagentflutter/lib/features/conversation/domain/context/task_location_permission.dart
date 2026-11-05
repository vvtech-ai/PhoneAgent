import '../agent_protocol.dart';
import '../tools/conversation_permission.dart';
import 'conversation_permission_resume.dart';

class TaskLocationPermission {
  TaskLocationPermission(this.permissions);
  final ConversationPermissionSource permissions;
  ConversationPermissionSource forSession(String sessionId) =>
      _TaskPermissionSource(this, sessionId);
  final _restaurantSessions = <String>{};
  final _asked = <String>{};
  final _denied = <String>{};
  final _prepared = <(String, String)>{};
  final _turns = <String, String>{};
  final _pending = <String, _LocationPermissionAttempt>{};
  bool isPending(String sessionId) => _pending[sessionId]?.isCurrent() == true;
  final _resumes = <String, (ConversationPermissionResume, void Function())>{};
  void Function() bindResume(
    String session,
    ConversationPermissionResume resume,
    void Function() beginSpeech,
  ) {
    final binding = (resume, beginSpeech);
    _resumes[session] = binding;
    return () {
      if (_resumes[session] == binding) {
        _resumes.remove(session);
        resume.background();
      }
    };
  }

  Future<void> prepare(AgentCommand command, bool Function() isCurrent) async {
    if (!isCurrent() ||
        command.actionId != null ||
        command.message?.trim().isNotEmpty != true) {
      return;
    }
    if (command.initialSkillId == 'restaurant_booking') {
      if (command.selectedContact != null) return;
      _restaurantSessions.add(command.sessionId);
    }
    if (!_prepared.add((command.sessionId, command.commandId))) return;
    _turns[command.sessionId] = command.commandId;
    if (RegExp(
      '(不要|不用|不需要|不想|不允许|不授权|不提供|别|拒绝).{0,8}(定位|位置)|不定位',
    ).hasMatch(command.message!)) {
      _asked.add(command.sessionId);
      _denied.add(command.sessionId);
      return;
    }
    final explicitAuthorization = RegExp(
      '(授权|开启|申请|打开|获取).{0,4}定位|(重新|再).{0,6}(定位|位置)',
    ).hasMatch(command.message!);
    final nearby = RegExp('附近|周边|离我最近|我这里|我的位置').hasMatch(command.message!);
    if (explicitAuthorization || nearby) {
      _asked.remove(command.sessionId);
      _denied.remove(command.sessionId);
    }
    if ((!nearby &&
            !explicitAuthorization &&
            !_restaurantSessions.contains(command.sessionId)) ||
        _asked.contains(command.sessionId)) {
      return;
    }
    final session = command.sessionId;
    final pending = _pending[session];
    if (pending != null && pending.isCurrent()) {
      await pending.future;
      return;
    }
    final binding = _resumes[session];
    final generation = binding?.$1.generation;
    final attempt = _LocationPermissionAttempt(
      () =>
          isCurrent() &&
          _resumes[session] == binding &&
          binding?.$1.generation == generation,
    );
    _pending[session] = attempt;
    attempt.future = _resolveInForeground(session, attempt.isCurrent)
        .whenComplete(() {
          if (identical(_pending[session], attempt)) _pending.remove(session);
        });
    await attempt.future;
  }

  Future<void> _resolveInForeground(
    String session,
    bool Function() isCurrent,
  ) async {
    final binding = _resumes[session];
    if (binding == null) {
      await _resolve(session, isCurrent);
      return;
    }
    final grant = await binding.$1.run(
      (valid) => _resolve(session, valid),
      isCurrent,
    );
    if (grant != null && isCurrent()) binding.$2();
  }

  Future<PermissionGrant?> _resolve(
    String session,
    bool Function() isCurrent,
  ) async {
    try {
      final source = _TaskPermissionSource(this, session, isCurrent);
      final grant = await source.resolve(
        ConversationPermission.location,
        request: false,
      );
      if (!isCurrent() ||
          grant != PermissionGrant.denied ||
          !_asked.add(session)) {
        return null;
      }
      return await source.resolve(
        ConversationPermission.location,
        request: true,
      );
    } catch (_) {
      // A failed capability check must not prevent a task using an explicit place.
      // The fresh context still reports the actual permission status to the Agent.
      return null;
    }
  }
}

class _TaskPermissionSource implements ConversationPermissionSource {
  const _TaskPermissionSource(this.owner, this.session, [this.isCurrent]);
  final TaskLocationPermission owner;
  final String session;
  final bool Function()? isCurrent;

  @override
  Future<PermissionGrant> resolve(
    ConversationPermission permission, {
    required bool request,
  }) async {
    final location = permission == ConversationPermission.location;
    if (location && request && owner._denied.contains(session)) {
      return PermissionGrant.denied;
    }
    final turn = owner._turns[session];
    final binding = owner._resumes[session];
    final generation = binding?.$1.generation;
    final grant = await owner.permissions.resolve(permission, request: request);
    if (isCurrent?.call() == false ||
        owner._turns[session] != turn ||
        owner._resumes[session] != binding ||
        binding?.$1.generation != generation) {
      return grant;
    }
    if (location && grant == PermissionGrant.granted) {
      owner._denied.remove(session);
    }
    if (location && request && grant == PermissionGrant.denied) {
      owner._denied.add(session);
    }
    return grant;
  }
}

class _LocationPermissionAttempt {
  _LocationPermissionAttempt(this.isCurrent);
  final bool Function() isCurrent;
  late final Future<void> future;
}
