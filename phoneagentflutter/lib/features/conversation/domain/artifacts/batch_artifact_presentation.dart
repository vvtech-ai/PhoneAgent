import '../conversation_messages.dart';
import 'task_artifact.dart';

/// Groups only owned batch CSVs; templates and unrelated messages keep order.
abstract final class BatchArtifactPresentation {
  static List<ConversationMessage> project(
    Iterable<ConversationMessage> messages,
  ) {
    final source = messages.toList();
    final batches = {
      for (final message in source)
        if (message.batchReceipt != null) message.batchReceipt!.id,
    };
    final attached = <String, Map<String, ConversationMessage>>{};
    for (final message in source) {
      final artifact = message.artifact;
      if (artifact?.kind != TaskArtifactKind.batchCsv ||
          artifact!.sourceBatchId.isEmpty ||
          !batches.contains(artifact.sourceBatchId)) {
        continue;
      }
      attached.putIfAbsent(artifact.sourceBatchId, () => {})[artifact.id] =
          message;
    }
    final ids = {
      for (final group in attached.values)
        for (final artifact in group.values) artifact.id,
    };
    return List.unmodifiable([
      for (final message in source)
        if (!ids.contains(message.id)) ...[
          message,
          if (message.batchReceipt case final batch?)
            ...?attached.remove(batch.id)?.values,
        ],
    ]);
  }
}
