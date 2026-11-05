import 'trusted_incoming_identity.dart';

/// The display isolate receives snapshots; it never owns account or SDK state.
abstract interface class TrustedIdentityDisplayPort {
  Stream<TrustedIncomingIdentity?> get updates;
  Future<void> ready();
  Future<void> rendered(String presentationId);
  Future<void> dismiss(String presentationId);
  Future<void> dispose();
}
