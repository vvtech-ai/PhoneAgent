import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/points_activation.dart';
import '../../domain/points_wallet.dart';

/// Account-scoped foreground work. No SMS, local rewards or billing writes.
class PointsSessionController extends StateNotifier<List<String>> {
  PointsSessionController({
    required this.activate,
    required this.refresh,
    required this.acceptAccount,
    required this.isCurrent,
    this.loginAccount,
    this.loginGrants = const [],
    this.interval = const Duration(seconds: 30),
  }) : super(const []);
  final Future<PointsActivation?> Function() activate;
  final Future<void> Function() refresh;
  final void Function(PointsAccount) acceptAccount;
  final bool Function() isCurrent;
  final PointsAccount? loginAccount;
  final List<PointsGrant> loginGrants;
  final Duration interval;
  Timer? _timer;
  Future<void>? _work;
  bool _foreground = false, _initialized = false;
  bool get _current => mounted && isCurrent();

  void setForeground(bool value) {
    if (!_current || value == _foreground) return;
    _foreground = value;
    _timer?.cancel();
    _timer = null;
    if (value) unawaited(synchronize());
  }

  Future<void> synchronize() {
    if (!_current || !_foreground) return Future.value();
    if (_work != null) return _work!;
    _timer?.cancel();
    late final Future<void> work;
    work = _run().whenComplete(() {
      if (identical(_work, work)) _work = null;
      if (_current && _foreground) {
        _timer = Timer(interval, synchronize);
      }
    });
    _work = work;
    return work;
  }

  Future<void> _run() async {
    if (!_initialized) {
      _initialized = true;
      if (loginAccount != null) acceptAccount(loginAccount!);
      _notify(loginGrants);
    }
    try {
      final result = await activate();
      if (!_current) return;
      if (result != null) {
        acceptAccount(result.account);
        _notify(result.grants);
      }
    } catch (_) {
      // A later foreground cycle may retry; no recursive write retry.
    }
    if (!_current) return;
    try {
      await refresh();
    } catch (_) {
      // The shared wallet owns stale/error/retry UI, not a second error source.
    }
  }

  void _notify(List<PointsGrant> grants) {
    if (!_current) return;
    final notices = grants.map((event) => event.notice).whereType<String>();
    if (notices.isNotEmpty) state = List.unmodifiable([...state, ...notices]);
  }

  List<String> takeNotices() {
    if (!_current) return const [];
    final notices = state;
    if (state.isNotEmpty) state = const [];
    return notices;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
