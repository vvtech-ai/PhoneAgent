import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/trusted_identity_surface_port.dart';
import '../../domain/trusted_incoming_identity.dart';

/// Runs from identity events even when UIKit has paused the root Flutter view.
/// State contains only the identity to show in the ordinary Flutter Navigator.
class TrustedIdentitySurfaceController
    extends StateNotifier<TrustedIncomingIdentity?> {
  TrustedIdentitySurfaceController({
    required this.port,
    required this.onDismiss,
    required this.onDiagnostic,
  }) : super(null) {
    _subscription = port.events.listen(_receive);
  }
  final TrustedIdentitySurfacePort port;
  final void Function(String) onDismiss, onDiagnostic;
  StreamSubscription<TrustedIdentitySurfaceEvent>? _subscription;
  TrustedIncomingIdentity? _identity;
  bool _running = false, _dirty = false;
  int _version = 0, _attempts = 0;
  Timer? _retry;

  void update(TrustedIncomingIdentity? identity) {
    _identity = identity;
    _attempts = 0;
    // Immediately clear an old ordinary route on account invalidation.
    if (identity == null) state = null;
    _schedule();
  }

  void _receive(TrustedIdentitySurfaceEvent event) {
    if (!mounted) return;
    if (event.kind == 'retry') {
      _attempts = 0;
      _schedule();
      return;
    }
    if (_identity?.presentationId != event.presentationId) return;
    if (event.kind == 'dismissed') onDismiss(event.presentationId);
    if (event.kind == 'presented') onDiagnostic('IOS_PRESENTED');
  }

  void _schedule() {
    if (!mounted) return;
    _retry?.cancel();
    _version++;
    _dirty = true;
    if (!_running) unawaited(_drain());
  }

  Future<void> _drain() async {
    _running = true;
    try {
      while (mounted && _dirty) {
        _dirty = false;
        final version = _version;
        final identity = _identity;
        final result = await port.synchronize(identity);
        if (!mounted || version != _version) continue;
        state = result == TrustedIdentitySurfaceResult.fallback
            ? identity
            : null;
        if (result == TrustedIdentitySurfaceResult.deferred &&
            identity != null) {
          onDiagnostic('IOS_PRESENTATION_DEFERRED');
          if (_attempts++ < 12) {
            _retry = Timer(const Duration(milliseconds: 250), _schedule);
          }
        }
      }
    } finally {
      _running = false;
    }
  }

  @override
  void dispose() {
    _retry?.cancel();
    unawaited(_subscription?.cancel());
    _identity = null;
    super.dispose();
  }
}
