import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../contacts/domain/contact_records.dart';
import '../../domain/dial_contact_suggestion.dart';

class DialContactsState {
  const DialContactsState({
    this.entries = const [],
    this.loading = false,
    this.access = ContactAccess.unknown,
    this.failed = false,
  });
  final List<DialContactEntry> entries;
  final bool loading, failed;
  final ContactAccess access;
}

class DialContactsController extends StateNotifier<DialContactsState> {
  DialContactsController(this._source, this._policy)
    : super(const DialContactsState());
  final DeviceContactSource _source;
  final DialSuggestionPolicy _policy;
  Future<void> load() async {
    if (!mounted || state.loading) return;
    // Discard stale contacts before checking whether permission was revoked.
    state = const DialContactsState(loading: true);
    try {
      final snapshot = await _source.load(requestPermission: false);
      if (!mounted) return;
      state = DialContactsState(
        access: snapshot.access,
        entries: snapshot.canRead ? _policy.index(snapshot.rows) : const [],
      );
    } catch (_) {
      if (mounted) state = const DialContactsState(failed: true);
    }
  }
}
