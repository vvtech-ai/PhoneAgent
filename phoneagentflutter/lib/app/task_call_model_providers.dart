import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/call_models/domain/call_models.dart';

typedef TaskCallModelReader = ({String? modelId, bool ready})? Function();

/// Reads the existing task owner without keeping another copy of its state.
class TaskCallModelSource {
  TaskCallModelReader? _read;

  void Function() bind(TaskCallModelReader read) {
    _read = read;
    return () {
      if (identical(_read, read)) _read = null;
    };
  }

  CallModel? resolve(CallModelCatalog? catalog) {
    final task = _read?.call();
    if (task == null) return catalog?.current;
    final id = task.modelId;
    if (!task.ready || id == null || id.trim().isEmpty) return null;
    return catalog?.models
        .where(
          (model) =>
              model.available &&
              normalizeProvider(model.id) == normalizeProvider(id),
        )
        .firstOrNull;
  }
}

final taskCallModelSourceProvider = Provider.autoDispose
    .family<TaskCallModelSource, String>(
      (ref, sessionId) => TaskCallModelSource(),
    );
