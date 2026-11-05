import 'dart:convert';
import '../history/ledger_event.dart';
import '../conversation_messages.dart';
import 'task_artifact.dart';

/// Display facts only: never invokes download, a tool, or a task transition.
abstract final class TaskArtifactProjection {
  static Map<String, Object?> _object(Object? raw) {
    if (raw is String) {
      try {
        raw = jsonDecode(raw);
      } catch (_) {
        return const {};
      }
    }
    return raw is Map<String, Object?> ? raw : const {};
  }

  static List<ConversationMessage> messages(
    Map<String, Object?> payload,
    String? command,
  ) {
    final artifacts = <String, TaskArtifact>{};
    void collect(Object? raw) {
      final artifact = TaskArtifact.parse(raw);
      if (artifact != null) artifacts[artifact.id] = artifact;
    }

    var body = payload;
    for (var depth = 0; depth < 4 && body.isNotEmpty; depth++) {
      collect(body['artifact']);
      final batch = _object(body['batchCallResult']);
      if (batch['artifacts'] case final List rows) {
        for (final row in rows) {
          collect(row);
        }
      }
      final result = _object(body['result']);
      body = result.isNotEmpty ? result : _object(body['text']);
    }
    return [
      for (final artifact in artifacts.values)
        ConversationMessage(
          id: 'artifact:${artifact.id}',
          role: MessageRole.assistant,
          text: '',
          commandId: command,
          artifact: artifact,
        ),
    ];
  }

  static List<ConversationMessage> fromEvent(LedgerEvent event) =>
      event.schemaVersion == 1 &&
          {
            'TOOL_RESULT_RECORDED',
            'ASSISTANT_TURN_COMMITTED',
          }.contains(event.type)
      ? messages(event.payload, event.commandId)
      : const [];
}
