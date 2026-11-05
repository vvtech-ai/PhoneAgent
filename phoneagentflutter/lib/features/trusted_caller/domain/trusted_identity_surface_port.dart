import 'trusted_incoming_identity.dart';

enum TrustedIdentitySurfaceResult { fallback, overlay, deferred }

class TrustedIdentitySurfaceEvent {
  const TrustedIdentitySurfaceEvent(this.kind, this.presentationId);
  final String kind;
  final String presentationId;
}

abstract interface class TrustedIdentitySurfacePort {
  Stream<TrustedIdentitySurfaceEvent> get events;
  Future<TrustedIdentitySurfaceResult> synchronize(
    TrustedIncomingIdentity? value,
  );
  Future<void> dispose();
}
