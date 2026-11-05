import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/tools/conversation_permission.dart';
import 'package:phone_agent/features/conversation/domain/tools/conversation_permission_access.dart';

class AccessSource
    implements
        ConversationPermissionSource,
        ConversationPermissionSettingsSource {
  PermissionGrant grant = PermissionGrant.denied;
  final requests = <bool>[];
  Completer<void>? settingsResult;
  @override
  Future<void> openSettings() async => settingsResult?.future;
  @override
  Future<PermissionGrant> resolve(
    ConversationPermission permission, {
    required bool request,
  }) async {
    requests.add(request);
    return grant;
  }
}

void main() {
  test(
    'opening settings alone does not grant access or request again',
    () async {
      final source = AccessSource()..grant = PermissionGrant.blocked;
      final access = ConversationPermissionAccess(source);
      expect(
        await access.settings(ConversationPermission.location, () => true),
        PermissionGrant.blocked,
      );
      expect(source.requests, [false]);
    },
  );
  test(
    'settings completion from obsolete owner cannot read or grant',
    () async {
      final source = AccessSource()..settingsResult = Completer<void>();
      var current = true;
      final result = ConversationPermissionAccess(
        source,
      ).settings(ConversationPermission.microphone, () => current);
      current = false;
      source.grant = PermissionGrant.granted;
      source.settingsResult!.complete();
      expect(await result, isNull);
      expect(source.requests, isEmpty);
    },
  );
  test('blocked admission checks but does not re-request OS dialog', () async {
    final source = AccessSource()..grant = PermissionGrant.blocked;
    expect(
      await ConversationPermissionAccess(
        source,
      ).request(ConversationPermission.microphone, () => true),
      PermissionGrant.blocked,
    );
    expect(source.requests, [false]);
  });
}
