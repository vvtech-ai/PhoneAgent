import '../agent_protocol.dart';

enum ConversationPermission { microphone, contacts, location, documentPicker }

enum PermissionGrant { granted, denied, blocked, unavailable }

const locationPermissionSettingsNotice = '定位权限需要在系统设置中开启';
const locationPermissionDeniedToast = '未获得定位权限，可告诉我城市或区域。';
const locationPermissionBlockedToast = '定位权限未开启，可在系统设置中授权或告诉我具体区域。';

bool isLocationPermissionToast(String notice) =>
    notice == locationPermissionDeniedToast ||
    notice == locationPermissionBlockedToast;

abstract interface class ConversationPermissionSource {
  Future<PermissionGrant> resolve(
    ConversationPermission permission, {
    required bool request,
  });
}

/// Optional user-initiated settings capability; opening settings is not a grant.
abstract interface class ConversationPermissionSettingsSource {
  Future<void> openSettings();
}

class ConversationPermissionRequest {
  const ConversationPermissionRequest(this.permission, this.androidPermission);
  final ConversationPermission permission;
  final String? androidPermission;
  String get key => permission == ConversationPermission.documentPicker
      ? 'document_picker'
      : permission.name;

  factory ConversationPermissionRequest.parse(Map<String, Object?> payload) {
    final nested = payload['permissionRequest'];
    final data = nested is Map<String, Object?> && nested.isNotEmpty
        ? nested
        : payload;
    final key = data['permissionKey'];
    final permission = switch (key) {
      'microphone' => ConversationPermission.microphone,
      'contacts' => ConversationPermission.contacts,
      'location' => ConversationPermission.location,
      'document_picker' => ConversationPermission.documentPicker,
      _ => throw const FormatException('Unsupported permission key'),
    };
    final raw = data['androidPermission'];
    if (raw != null && raw is! String) {
      throw const FormatException('Invalid permission identifier');
    }
    final android = (raw as String?)?.trim();
    final expected = switch (permission) {
      ConversationPermission.microphone => 'android.permission.RECORD_AUDIO',
      ConversationPermission.contacts => 'android.permission.READ_CONTACTS',
      ConversationPermission.location =>
        'android.permission.ACCESS_FINE_LOCATION',
      ConversationPermission.documentPicker => null,
    };
    if (android != null && android.isNotEmpty && android != expected) {
      throw const FormatException('Permission identifier mismatch');
    }
    return ConversationPermissionRequest(
      permission,
      android == null || android.isEmpty ? null : android,
    );
  }
}

/// Resolves live requests only. Restored pending tools never call this class.
class ConversationPermissionCoordinator {
  ConversationPermissionCoordinator(this.source);
  final ConversationPermissionSource source;
  final _handled = <String>{};

  Future<ConversationPermissionResult?> resolve(
    AgentEvent event, {
    required bool Function() isCurrent,
  }) async {
    if (!isCurrent()) return null;
    final tool = event.payload['pendingToolCallId'];
    if (tool is! String || tool.trim().isEmpty) {
      throw const FormatException('Missing permission tool identity');
    }
    final permission = ConversationPermissionRequest.parse(event.payload);
    if (!_handled.add(tool)) return null;
    var grant = permission.permission == ConversationPermission.documentPicker
        ? PermissionGrant.granted
        : await source.resolve(permission.permission, request: false);
    if (!isCurrent()) return null;
    var requested = false;
    if (grant == PermissionGrant.denied) {
      requested = true;
      grant = await source.resolve(permission.permission, request: true);
      if (!isCurrent()) return null;
    }
    final status = grant == PermissionGrant.granted
        ? 'OK'
        : grant == PermissionGrant.unavailable ||
              grant == PermissionGrant.blocked ||
              !requested
        ? 'SETTINGS_REQUIRED'
        : 'DENIED';
    return ConversationPermissionResult({
      'permissionKey': permission.key,
      if (permission.androidPermission != null)
        'androidPermission': permission.androidPermission,
      'status': status,
      'granted': grant == PermissionGrant.granted,
      'message': switch (status) {
        'OK' => requested ? '授权成功' : '授权能力可用',
        'DENIED' => '用户未授权',
        _ => '该权限当前不可用，请在支持的平台或系统设置中检查',
      },
    });
  }
}

class ConversationPermissionResult {
  const ConversationPermissionResult(this.payload);
  final Map<String, Object?> payload;
  AgentCommand command(
    String session,
    String user,
    String id,
    String trace,
    Map<String, Object?>? context,
  ) => AgentCommand(
    sessionId: session,
    userId: user,
    commandId: id,
    idempotencyKey: id,
    traceId: trace,
    actionId: 'permission_result',
    actionPayload: payload,
    userContext: context,
  );
}
