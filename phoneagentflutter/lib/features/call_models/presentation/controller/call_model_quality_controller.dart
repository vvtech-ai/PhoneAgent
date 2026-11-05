import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/call_models.dart';
import '../../domain/call_model_quality.dart';

class CallModelQualityState {
  const CallModelQualityState({this.readings = const {}, this.busy = false});
  final Map<String, CallModelReading> readings;
  final bool busy;
}

class CallModelQualityController extends StateNotifier<CallModelQualityState> {
  CallModelQualityController(this._repository)
    : super(const CallModelQualityState());
  final CallModelQualityRepository _repository;
  int _generation = 0;
  Future<void> refresh(Iterable<String> models) async {
    if (!mounted || state.busy) return;
    final requested = models.map(normalizeProvider).toSet();
    if (requested.isEmpty) return;
    final generation = ++_generation;
    state = CallModelQualityState(readings: state.readings, busy: true);
    Map<String, CallModelReading> result;
    try {
      result = await _repository.refresh();
    } catch (_) {
      result = const {};
    }
    if (!mounted || generation != _generation) return;
    state = CallModelQualityState(
      readings: Map.unmodifiable({
        for (final id in requested)
          id: result[id] ?? const CallModelReading.unknown(),
      }),
    );
  }

  void cancel() {
    if (!mounted) return;
    _generation++;
    state = const CallModelQualityState();
  }
}
