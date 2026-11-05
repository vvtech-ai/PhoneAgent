import 'package:flutter/services.dart';
import '../../domain/artifacts/task_artifact.dart';
import '../../domain/artifacts/task_artifact_download.dart';

class DeviceTaskFileDestination
    implements TaskFileDestination, TaskFileInspection {
  const DeviceTaskFileDestination({
    this.channel = const MethodChannel('phone_agent/task_files'),
  });
  final MethodChannel channel;
  @override
  Future<TaskFileSaved?> save(
    String operationId,
    TaskArtifact artifact,
    Uint8List bytes,
  ) async {
    final location = await channel.invokeMethod<String>('save', {
      'id': operationId,
      'name': artifact.fileName,
      'mime': artifact.mimeType.split(';').first,
      'bytes': bytes,
    });
    if (location == null) return null;
    if (location.isEmpty) throw const FormatException('Invalid saved file');
    return TaskFileSaved(location);
  }

  @override
  Future<bool> exists(TaskFileSaved saved) async =>
      await channel.invokeMethod<bool>('exists', {
        'location': saved.location,
      }) ??
      false;

  @override
  Future<void> cancel(String operationId) =>
      channel.invokeMethod<void>('cancel', {'id': operationId});
  @override
  Future<void> open(TaskFileSaved saved) =>
      channel.invokeMethod<void>('open', {'location': saved.location});
}
