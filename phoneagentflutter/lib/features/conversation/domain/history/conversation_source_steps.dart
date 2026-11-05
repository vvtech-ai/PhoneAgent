import 'dart:convert';
import '../conversation_messages.dart';
import '../membership_denial_reply.dart';
import '../call_confirmation.dart';
import '../receipts/batch_receipt_projector.dart';
import '../receipts/call_receipt_projector.dart';
import 'batch_confirmation_projector.dart';
import 'ledger_event.dart';

class ConversationSourceStep {
  const ConversationSourceStep(
    this.id,
    this.sequence,
    this.order,
    this.aliases, {
    this.contributes = true,
  });
  final String id;
  final int sequence, order;
  final Set<String> aliases;
  final bool contributes;
}

/// v65's timeline-to-ClarificationStep boundary, BEFORE display deduplication.
/// Includes supported source facts whose Flutter card is not yet implemented.
abstract final class ConversationSourceSteps {
  static List<ConversationSourceStep> project(Iterable<LedgerEvent> facts) {
    final events = facts.toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    final superseded = <String>{}, committed = <String>{};
    for (final e in events) {
      if (e.schemaVersion != 1) continue;
      if (e.type == 'ASSISTANT_TURN_COMMITTED' && e.commandId != null) {
        committed.add(e.commandId!);
      }
      if (e.type == 'RUN_CANCELLED' &&
          e.payload['stage'] == 'recovery_revision' &&
          e.commandId != null &&
          !committed.contains(e.commandId)) {
        superseded.add(e.commandId!);
      }
    }
    final eligible = events
        .where(
          (e) =>
              e.schemaVersion == 1 &&
              !(superseded.contains(e.commandId) &&
                  const {
                    'USER_TURN_ACCEPTED',
                    'ASSISTANT_TURN_COMMITTED',
                    'TOOL_REQUESTED',
                    'TOOL_RESULT_RECORDED',
                  }.contains(e.type)),
        )
        .toList();
    final items = <(String, String), ConversationSourceStep>{};
    void upsert(
      String id,
      LedgerEvent e, {
      int order = 0,
      bool contributes = true,
      bool eventAlias = true,
      Set<String> aliases = const {},
    }) {
      final key = (e.sessionId, id);
      final old = items[key];
      items[key] = ConversationSourceStep(
        id,
        old?.sequence ?? e.sequence,
        old?.order ?? order,
        {
          ...?old?.aliases,
          if (eventAlias) 'ledger:${e.eventId}',
          id,
          ...aliases,
        },
        contributes: contributes || (old?.contributes ?? false),
      );
    }

    final batchEvents = eligible.where(
      (e) =>
          !(e.type == 'TOOL_RESULT_RECORDED' &&
              ((e.payload['toolName'] == 'confirmBatchTask' &&
                      _text(e.payload, 'toolCallId').trim().isNotEmpty) ||
                  (e.payload['toolName'] == 'provideSkillTemplate' &&
                      _validArtifact(
                        _object(_object(e.payload['result'])['artifact']),
                      )))),
    );
    for (final batch in BatchReceiptProjector.project(batchEvents)) {
      upsert(
        'ledger:batch:${batch.receipt.id}',
        batch.anchor,
        eventAlias: false,
      );
    }
    final explicitBatches = events
        .map((e) => _text(BatchReceiptProjector.payload(e.payload), 'batchId'))
        .where((id) => id.isNotEmpty)
        .toSet();
    final callTasks = <String, String>{};
    for (final e in events) {
      if (e.schemaVersion == 1 &&
          CallReceiptProjector.callTypes.contains(e.type) &&
          (e.callAttemptId?.trim().isNotEmpty ?? false) &&
          (e.taskId?.trim().isNotEmpty ?? false)) {
        callTasks.putIfAbsent(e.callAttemptId!.trim(), () => e.taskId!);
      }
    }
    for (final call in CallReceiptProjector.project(events)) {
      if (!explicitBatches.contains(
        callTasks[call.receipt.attemptId] ?? call.anchor.taskId,
      )) {
        upsert(
          'ledger:call:${call.receipt.attemptId}',
          call.anchor,
          eventAlias: false,
        );
      }
    }
    final executionRequests = BatchConfirmationProjector.executionRequestIds(
      eligible,
    );
    final executionCards = <(String, String), Set<String>>{};
    for (final e in eligible) {
      final p = e.payload, args = _object(e.payload['arguments']);
      final tool = _text(p, 'toolName'), toolId = _text(p, 'toolCallId').trim();
      final fallback = 'ledger:${e.eventId}';
      if (e.type == 'USER_TURN_ACCEPTED') {
        final document = _objectOrJson(p['text']);
        final batchId = _text(document, 'documentBatchId').trim();
        final validBatch =
            _text(p, 'inputKind').toLowerCase() == 'document' &&
            document['schema'] == 'user_document_batch.v1' &&
            document['documents'] is List &&
            (document['documents'] as List).whereType<Map>().isNotEmpty;
        upsert(
          validBatch && batchId.isNotEmpty
              ? 'ledger:document-batch:$batchId'
              : fallback,
          e,
        );
      } else if (e.type == 'ASSISTANT_TURN_COMMITTED') {
        if (_text(p, 'text').trim().isNotEmpty) upsert(fallback, e, order: 1);
      } else if (e.type == 'MEMORY_OPERATION_NOTICE') {
        if (_text(p, 'text').trim().isNotEmpty) {
          upsert('ledger:memory-notice:${e.eventId}', e, order: 1);
        }
      } else if (e.type == 'RUN_FAILED' &&
          !superseded.contains(e.commandId) &&
          MembershipDenialReply.message(p['reason']) != null) {
        if (p['reason'] == 'BATCH_CONTACT_LIMIT' && e.commandId != null) {
          for (final id
              in executionCards[(e.sessionId, e.commandId!)] ??
                  const <String>{}) {
            items.remove((e.sessionId, id));
          }
        }
        upsert(fallback, e, order: 1);
      } else if (e.type == 'TOOL_REQUESTED') {
        if (tool == 'confirmBatchTask') {
          if (p['displayPayloadVersion'] == 1 &&
              toolId.isNotEmpty &&
              _objectOrJson(args['snapshotJson']).isNotEmpty) {
            upsert('ledger:batch-confirmation:$toolId', e);
          }
        } else if (executionRequests.contains(e.eventId)) {
          continue;
        } else if (const {'makeCall', 'makeBatchCalls'}.contains(tool)) {
          if (CallConfirmation.fromPayload(
            args,
            batch: tool == 'makeBatchCalls',
          ).hasContent) {
            final id = toolId.isEmpty
                ? fallback
                : 'ledger:call-confirmation:$toolId';
            upsert(id, e, aliases: {'$id:prompt'});
            if (tool == 'makeBatchCalls' && e.commandId != null) {
              executionCards
                  .putIfAbsent((e.sessionId, e.commandId!), () => <String>{})
                  .add(
                    toolId.isEmpty
                        ? fallback
                        : 'ledger:call-confirmation:$toolId',
                  );
            }
          }
        } else if (p['displayPayloadVersion'] == 1 && p['arguments'] is Map) {
          if ((tool == 'askUser' &&
                  ConversationMessages.questions(args).isNotEmpty) ||
              const {'requestPermission', 'importDocument'}.contains(tool) ||
              (tool == 'showOptions' &&
                  ConversationMessages.options(args).isNotEmpty)) {
            upsert(fallback, e);
          }
        }
      } else if (e.type == 'TOOL_RESULT_RECORDED') {
        if (const {
              'makeCall',
              'makeBatchCalls',
              'confirmBatchTask',
            }.contains(tool) &&
            const {
              'rejected',
              'policy_rejected',
            }.contains(_text(p, 'resultStatus').toLowerCase()) &&
            toolId.isNotEmpty) {
          final id = tool == 'confirmBatchTask'
              ? 'ledger:batch-confirmation:$toolId'
              : 'ledger:call-confirmation:$toolId';
          items.remove((e.sessionId, id));
        } else if (tool == 'confirmBatchTask') {
          if (toolId.isNotEmpty) {
            upsert('ledger:batch-confirmation:$toolId', e, contributes: false);
          }
        } else if (tool == 'provideSkillTemplate') {
          final artifact = _object(_object(p['result'])['artifact']);
          if ([
            'artifactId',
            'kind',
            'fileName',
            'mimeType',
            'status',
          ].every((k) => _text(artifact, k).trim().isNotEmpty)) {
            upsert('ledger:artifact:${_text(artifact, 'artifactId')}', e);
          }
        }
      }
    }
    final result = items.values.toList()
      ..sort((a, b) {
        if (a.sequence != b.sequence) return a.sequence.compareTo(b.sequence);
        if (a.order != b.order) return a.order.compareTo(b.order);
        return a.id.compareTo(b.id);
      });
    return List.unmodifiable(result);
  }

  static String _text(Map<String, Object?> map, String key) =>
      map[key] is String ? map[key] as String : '';
  static bool _validArtifact(Map<String, Object?> data) => [
    'artifactId',
    'kind',
    'fileName',
    'mimeType',
    'status',
  ].every((key) => _text(data, key).trim().isNotEmpty);
  static Map<String, Object?> _object(Object? value) =>
      value is Map<String, Object?> ? value : const {};
  static Map<String, Object?> _objectOrJson(Object? value) {
    if (value is String) {
      try {
        value = jsonDecode(value);
      } catch (_) {
        return const {};
      }
    }
    return _object(value);
  }
}
