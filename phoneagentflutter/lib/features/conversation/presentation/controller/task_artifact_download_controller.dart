import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/conversation_ids.dart';
import '../../domain/artifacts/task_artifact.dart';
import '../../domain/artifacts/task_artifact_download.dart';

class TaskArtifactDownloadController extends ChangeNotifier {
  TaskArtifactDownloadController({
    required this.repository,
    required this.destination,
    required this.isCurrent,
  });
  final TaskArtifactRepository repository;
  final TaskFileDestination destination;
  final bool Function() isCurrent;
  final _states = <String, ArtifactDownloadState>{};
  final _operations = <String, String>{};
  bool _closed = false;
  bool get _current => !_closed && isCurrent();
  ArtifactDownloadState state(String id) =>
      _states[id] ?? const ArtifactDownloadState(ArtifactDownloadPhase.idle);
  void _set(String id, ArtifactDownloadState state) {
    if (!_current) return;
    _states[id] = state;
    notifyListeners();
  }

  Future<void> download(TaskArtifact artifact) async {
    if (!_current ||
        !artifact.ready ||
        _operations.containsKey(artifact.id) ||
        state(artifact.id).phase == ArtifactDownloadPhase.saved) {
      return;
    }
    final operation = newConversationId();
    _operations[artifact.id] = operation;
    _set(
      artifact.id,
      const ArtifactDownloadState(ArtifactDownloadPhase.downloading),
    );
    bool active() => _current && _operations[artifact.id] == operation;
    try {
      final bytes = await repository.download(artifact);
      if (!active()) return;
      final saved = await destination.save(operation, artifact, bytes);
      if (!active()) return;
      _set(
        artifact.id,
        saved == null
            ? const ArtifactDownloadState(
                ArtifactDownloadPhase.cancelled,
                notice: '已取消保存，可重新下载。',
              )
            : ArtifactDownloadState(ArtifactDownloadPhase.saved, saved: saved),
      );
    } catch (_) {
      if (active()) {
        _set(
          artifact.id,
          const ArtifactDownloadState(
            ArtifactDownloadPhase.failed,
            notice: '文件下载或保存失败，请重试。',
          ),
        );
      }
    } finally {
      if (_operations[artifact.id] == operation) {
        _operations.remove(artifact.id);
      }
    }
  }

  Future<void> open(String id) async {
    final saved = state(id).saved;
    if (!_current || saved == null) return;
    try {
      if (!await _exists(saved)) {
        if (_current && identical(state(id).saved, saved)) _missing(id);
        return;
      }
      if (!_current || !identical(state(id).saved, saved)) return;
      await destination.open(saved);
    } catch (_) {
      _set(
        id,
        ArtifactDownloadState(
          ArtifactDownloadPhase.saved,
          saved: saved,
          notice: '无法打开文件，请在系统文件中查看。',
        ),
      );
    }
  }

  Future<bool> _exists(TaskFileSaved saved) async {
    final files = destination;
    return files is TaskFileInspection
        ? await (files as TaskFileInspection).exists(saved)
        : true;
  }

  void _missing(String id) => _set(
    id,
    const ArtifactDownloadState(
      ArtifactDownloadPhase.idle,
      notice: '本地文件已不存在，可重新下载。',
    ),
  );
  Future<void> refreshSaved() async {
    if (!_current) return;
    for (final entry in _states.entries.toList()) {
      final saved = entry.value.saved;
      if (saved == null) continue;
      try {
        final exists = await _exists(saved);
        if (!_current) return;
        if (!exists && identical(state(entry.key).saved, saved)) {
          _missing(entry.key);
        }
      } catch (_) {
        /* An unavailable inspection is not proof of deletion. */
      }
    }
  }

  @override
  void dispose() {
    _closed = true;
    for (final operation in _operations.values) {
      unawaited(destination.cancel(operation).catchError((_) {}));
    }
    _operations.clear();
    super.dispose();
  }
}
