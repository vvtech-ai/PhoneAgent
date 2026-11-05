import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/features/conversation/data/tools/preview_permission_session.dart';
import 'package:phone_agent/features/conversation/domain/tools/conversation_permission.dart';

final shellPermissionPortsProvider = Provider<ShellPermissionPorts>((ref) {
  ref.watch(loginEpochProvider);
  return ShellPermissionPorts();
});

/// Complete-App workbench only. Reuses the isolated permission source;
/// the formal coordinator still decides whether to check/request and continue.
class ShellPermissionPorts extends PreviewPermissionSession {
  @override
  Future<PermissionGrant> resolve(
    ConversationPermission permission, {
    required bool request,
  }) => permission == ConversationPermission.microphone
      ? Future.value(PermissionGrant.granted)
      : super.resolve(permission, request: request);

  bool selectCommand(String? message) {
    final selected = switch (message) {
      '演练权限允许' => PermissionPreviewScenario.allow,
      '演练权限拒绝' => PermissionPreviewScenario.deny,
      '演练权限设置' => PermissionPreviewScenario.settings,
      _ => null,
    };
    if (selected == null) return false;
    scenario = selected;
    return true;
  }
}
