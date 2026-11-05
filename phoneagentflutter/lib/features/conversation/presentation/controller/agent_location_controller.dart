import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/context/agent_location.dart';

/// Account-scoped, memory-only context. Route cancellation never sends a turn.
class AgentLocationController extends StateNotifier<AgentLocation?> {
  AgentLocationController(
    this.source, {
    Duration Function()? elapsed,
    this.timeout = const Duration(seconds: 10),
    this.ttl = const Duration(minutes: 2),
    this.maximumFallbackAge = const Duration(minutes: 5),
  }) : _elapsed = elapsed ?? (Stopwatch()..start()).elapsedDuration,
       super(null);
  final AgentLocationSource source;
  final Duration Function() _elapsed;
  final Duration timeout, ttl, maximumFallbackAge;
  Duration? _sampledAt;
  Future<Map<String, Object?>>? _pending;
  int _generation = 0;

  Future<Map<String, Object?>> context() {
    if (!mounted) return Future.value(const {});
    if (_sampledAt != null && _elapsed() - _sampledAt! < ttl) {
      return Future.value(state?.toContext() ?? const {});
    }
    return _pending ??= _refresh(
      ++_generation,
    ).whenComplete(() => _pending = null);
  }

  Future<Map<String, Object?>> _refresh(int generation) async {
    try {
      final value = await source.read().timeout(timeout);
      if (!mounted || generation != _generation) return const {};
      if (value != null) {
        state = value;
        _sampledAt = _elapsed();
      }
    } catch (_) {
      // Preserve the displayed snapshot; sending it still requires freshness.
      unawaited(source.cancel().catchError((Object _) {}));
    }
    if (!mounted || generation != _generation) return const {};
    if (_sampledAt == null || _elapsed() - _sampledAt! >= maximumFallbackAge) {
      return const {};
    }
    return state?.toContext() ?? const {};
  }

  @override
  void dispose() {
    _generation++;
    unawaited(source.cancel().catchError((Object _) {}));
    super.dispose();
  }
}

extension on Stopwatch {
  Duration elapsedDuration() => elapsed;
}
