import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/trusted_caller.dart';
import '../../domain/trusted_incoming_identity.dart';

class TrustedIncomingIdentityController
    extends StateNotifier<TrustedIncomingIdentity?> {
  TrustedIncomingIdentityController({
    required this.owner,
    required Stream<TrustedIncomingIdentity?> events,
    required bool Function(TrustedCallerOwner) isCurrent,
    this.onCleanupFailure,
  }) : _isCurrent = isCurrent,
       super(null) {
    _subscription = events.listen(
      _received,
      onError: (_) => _received(null),
      onDone: () => _received(null),
    );
  }
  final TrustedCallerOwner owner;
  final bool Function(TrustedCallerOwner) _isCurrent;
  final void Function(String code)? onCleanupFailure;
  StreamSubscription<TrustedIncomingIdentity?>? _subscription;
  String? _dismissedEventId;
  String? _latestEventId;
  int _latestRevision = 0;
  bool _invalidated = false;

  void _received(TrustedIncomingIdentity? event) {
    if (!mounted || _invalidated) return;
    if (!_isCurrent(owner)) {
      _invalidated = true;
      state = null;
      return;
    }
    if (event != null && !event.owner.matches(owner)) {
      state = null;
      return;
    }
    if (event != null) {
      if (event.eventId == _latestEventId &&
          event.presentationRevision < _latestRevision) {
        return;
      }
      _latestEventId = event.eventId;
      _latestRevision = event.presentationRevision;
      if (event.presentationId == _dismissedEventId) return;
    }
    state = event;
  }

  void dismiss(String eventId) {
    if (!mounted || state?.presentationId != eventId) return;
    _dismissedEventId = eventId;
    state = null;
  }

  @override
  void dispose() {
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) {
      unawaited(
        subscription.cancel().catchError((_) {
          onCleanupFailure?.call('TRUSTED_INCOMING_STREAM_RELEASE_UNCONFIRMED');
        }),
      );
    }
    super.dispose();
  }
}
