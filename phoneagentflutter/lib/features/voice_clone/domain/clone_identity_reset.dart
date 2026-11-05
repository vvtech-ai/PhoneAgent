import '../../identity/domain/identity_deletion_cleanup.dart';

/// A successful remote deletion is never replayed to retry local cleanup.
class CloneIdentityReset {
  CloneIdentityReset({
    required this.delete,
    required this.createCleanup,
    required this.isCurrent,
  });
  final Future<void> Function() delete;
  final IdentityDeletionCleanup Function() createCleanup;
  final bool Function() isCurrent;
  bool _deleted = false;
  IdentityDeletionCleanup? _cleanup;
  Future<bool>? _running;

  Future<bool> run() => _running ??= _run().whenComplete(() => _running = null);

  Future<bool> _run() async {
    if (!isCurrent()) return false;
    if (!_deleted) {
      await delete();
      _deleted = true;
    }
    if (!isCurrent()) return false;
    try {
      _cleanup ??= createCleanup();
      await _cleanup!.run();
      _deleted = false;
      _cleanup = null;
      return true;
    } catch (_) {
      return false;
    }
  }
}
