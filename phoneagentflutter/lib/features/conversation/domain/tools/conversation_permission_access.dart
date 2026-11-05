import 'conversation_permission.dart';

/// Admission checks read system state; opening settings never implies a grant.
class ConversationPermissionAccess {
  const ConversationPermissionAccess(this.source);
  final ConversationPermissionSource source;

  Future<PermissionGrant?> request(
    ConversationPermission permission,
    bool Function() current,
  ) async {
    if (!current()) return null;
    try {
      var grant = await source.resolve(permission, request: false);
      if (!current()) return null;
      if (grant == PermissionGrant.denied) {
        grant = await source.resolve(permission, request: true);
      }
      return current() ? grant : null;
    } catch (_) {
      return current() ? PermissionGrant.unavailable : null;
    }
  }

  Future<PermissionGrant?> settings(
    ConversationPermission permission,
    bool Function() current, {
    void Function()? onReturned,
  }) async {
    if (!current() || source is! ConversationPermissionSettingsSource) {
      return null;
    }
    try {
      await (source as ConversationPermissionSettingsSource).openSettings();
      if (!current()) return null;
      onReturned?.call();
      final grant = await source.resolve(permission, request: false);
      return current() ? grant : null;
    } catch (_) {
      return current() ? PermissionGrant.unavailable : null;
    }
  }
}
