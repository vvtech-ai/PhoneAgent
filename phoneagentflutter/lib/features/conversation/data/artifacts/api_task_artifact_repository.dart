import 'dart:typed_data';
import 'dart:convert';
import '../../../../core/network/account_api.dart';
import '../../../../core/network/account_session.dart';
import '../../domain/artifacts/task_artifact.dart';
import '../../domain/artifacts/task_artifact_download.dart';

class ApiTaskArtifactRepository implements TaskArtifactRepository {
  const ApiTaskArtifactRepository(this.api);
  final AccountApi api;
  @override
  Future<Uint8List> download(TaskArtifact artifact) async {
    if (!artifact.ready || !TaskArtifact.validId(artifact.id)) {
      throw ApiFailure.invalidResponse;
    }
    final bytes = await api.download(
      'api/agent-artifacts/${artifact.id}/content',
      maxBytes: 20 * 1024 * 1024,
      mediaTypes: {artifact.mimeType.split(';').first.trim().toLowerCase()},
    );
    if (artifact.kind == TaskArtifactKind.batchCsv) {
      final preview = utf8
          .decode(bytes.take(8192).toList(), allowMalformed: true)
          .replaceFirst('\uFEFF', '')
          .trimLeft();
      if (preview.startsWith('{') || preview.startsWith('<')) {
        throw ApiFailure.invalidResponse;
      }
    }
    return bytes;
  }
}
