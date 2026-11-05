import '../domain/dial_permission.dart';

/// Synthetic OS only. UI and state sequencing use the production controller.
class PreviewDialPermissionPort implements DialPermissionPort {
  PreviewDialPermissionPort({
    this.supportsCallLog = true,
    this.allowLocation = false,
  });
  @override
  final bool supportsCallLog;
  bool allowLocation;
  DialPermissionGrant grant = DialPermissionGrant.denied;
  final trace = <String>[];
  @override
  Future<DialPermissionGrant> location({bool request = false}) async {
    trace.add(request ? 'location:request' : 'location:check');
    if (request) {
      grant = allowLocation
          ? DialPermissionGrant.granted
          : DialPermissionGrant.blocked;
    }
    return grant;
  }

  @override
  Future<DialPermissionGrant> callLog({bool request = false}) async {
    trace.add(request ? 'callLog:request' : 'callLog:check');
    return request ? DialPermissionGrant.granted : DialPermissionGrant.denied;
  }

  @override
  Future<void> openSettings() async {
    trace.add('settings:open');
    grant = DialPermissionGrant.granted;
  }
}
