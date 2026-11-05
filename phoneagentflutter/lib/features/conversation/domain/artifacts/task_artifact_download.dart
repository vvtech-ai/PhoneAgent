import 'dart:typed_data';
import 'task_artifact.dart';

abstract interface class TaskArtifactRepository {
  Future<Uint8List> download(TaskArtifact artifact);
}

class TaskFileSaved {
  const TaskFileSaved(this.location);
  final String location;
}

abstract interface class TaskFileDestination {
  Future<TaskFileSaved?> save(
    String operationId,
    TaskArtifact artifact,
    Uint8List bytes,
  );
  Future<void> cancel(String operationId);
  Future<void> open(TaskFileSaved saved);
}

enum ArtifactDownloadPhase { idle, downloading, saved, cancelled, failed }

class ArtifactDownloadState {
  const ArtifactDownloadState(this.phase, {this.saved, this.notice = ''});
  final ArtifactDownloadPhase phase;
  final TaskFileSaved? saved;
  final String notice;
}

/// Optional local capability; no download or credential is involved.
abstract interface class TaskFileInspection {
  Future<bool> exists(TaskFileSaved saved);
}
