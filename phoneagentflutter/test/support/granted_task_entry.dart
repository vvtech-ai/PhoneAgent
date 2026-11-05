import 'package:phone_agent/features/conversation/domain/tools/conversation_permission.dart';

/// Synthetic entry admission for navigation tests; never reaches a device port.
class GrantedTaskEntry implements ConversationPermissionSource {
  const GrantedTaskEntry();
  @override
  Future<PermissionGrant> resolve(
    ConversationPermission permission, {
    required bool request,
  }) async => PermissionGrant.granted;
}
