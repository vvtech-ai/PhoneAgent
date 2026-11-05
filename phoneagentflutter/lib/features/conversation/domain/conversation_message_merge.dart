import 'dart:developer' as developer;

import '../../../core/diagnostics/diagnostic_journal.dart';
import 'conversation_messages.dart';
import 'conversation_live_messages.dart';
import 'conversation_message_presentation.dart';
import 'receipts/receipt_overlay.dart';
import 'artifacts/batch_artifact_presentation.dart';

/// Presentation overlay only: durable ledger facts stay authoritative.
abstract final class ConversationMessageMerge {
  static List<ConversationMessage> merge(
    List<ConversationMessage> durable,
    List<ConversationMessage> temporary,
  ) {
    _trace(
      'phase=start durable=${durable.length} temporary=${temporary.length}',
    );
    final visible = [...durable];
    final preludeOwners = <String, String>{};
    for (
      var temporaryIndex = 0;
      temporaryIndex < temporary.length;
      temporaryIndex++
    ) {
      var item = temporary[temporaryIndex];
      if (configuredDiagnosticLogLevel == DiagnosticLogLevel.debug) {
        _trace('phase=input index=$temporaryIndex ${_messageTrace(item)}');
      }
      final anchor = item.insertBeforeCommandId?.trim();
      if (item.id.startsWith('local:apology:') &&
          anchor != null &&
          anchor.isNotEmpty) {
        _mergeApologyPrelude(
          visible,
          durable,
          temporary,
          item,
          anchor,
          preludeOwners,
        );
        continue;
      }
      if (anchor != null && anchor.isNotEmpty) {
        final index = visible.indexWhere((m) => m.commandId == anchor);
        visible.insert(index < 0 ? visible.length : index, item);
        continue;
      }
      if (item.thinking != null) {
        final index = visible.indexWhere(
          (m) =>
              m.commandId == item.commandId && m.role == MessageRole.assistant,
        );
        final turnEnd = visible.lastIndexWhere(
          (m) => m.commandId == item.commandId,
        );
        final following = _followingTurnIndex(
          visible,
          durable,
          temporary,
          temporaryIndex,
        );
        visible.insert(
          index >= 0
              ? index
              : turnEnd >= 0
              ? turnEnd + 1
              : following >= 0
              ? following
              : visible.length,
          item,
        );
        continue;
      }
      if (ConversationLiveMessages.isMemoryNotice(item)) {
        if (durable.any(
          (m) =>
              m.commandId == item.commandId &&
              m.role == MessageRole.assistant &&
              (m.text == item.text || m.text.startsWith('${item.text}\n\n')),
        )) {
          continue;
        }
        final last = visible.lastIndexWhere(
          (m) => m.commandId == item.commandId,
        );
        final next = _followingOwnedMessageIndex(
          visible,
          temporary,
          temporaryIndex,
          item.commandId,
        );
        visible.insert(
          next >= 0
              ? next
              : last < 0
              ? visible.length
              : last + 1,
          item,
        );
        continue;
      }
      if (item.artifact != null) {
        if (visible.any((m) => m.artifact?.id == item.artifact!.id)) continue;
      }
      // A committed fact with the same turn/tool identity is authoritative.
      // Keep its original ledger position and do not append a second live copy.
      if (durable.any((fact) => _authoritativeMatch(fact, item))) continue;
      final isReceipt = item.receipt != null || item.batchReceipt != null;
      if (isReceipt) {
        final owner = visible.indexWhere(
          (fact) => ReceiptOverlay.matches(fact, item),
        );
        if (owner >= 0) {
          visible[owner] = ReceiptOverlay.promote(visible[owner], item);
          continue;
        }
      }
      bool sameTool(ConversationMessage fact) =>
          (item.toolCallId?.trim().isNotEmpty ?? false) &&
          (fact.commandId == item.commandId ||
              item.confirmation != null ||
              item.batchConfirmation != null) &&
          fact.toolCallId == item.toolCallId;
      if (item.confirmation != null) {
        final owner = durable
            .where((m) => m.confirmation != null && sameTool(m))
            .firstOrNull;
        if (owner != null) {
          if (item.text.trim().isEmpty ||
              item.text.trim() == owner.text.trim()) {
            continue;
          }
          item = item.copyWith(
            id: '${item.id}:narrative',
            clearConfirmation: true,
          );
        }
      }
      if (item.toolCard == null &&
          item.batchConfirmation == null &&
          durable.any(
            (m) =>
                m.batchConfirmation != null &&
                sameTool(m) &&
                m.text == item.text,
          )) {
        continue;
      }
      final replaced = isReceipt
          ? false
          : item.questions != null || item.questionSourceText != null
          ? durable.any(
              (m) =>
                  sameTool(m) &&
                  (m.questions != null ||
                      m.questionSourceText != null ||
                      (m.role == MessageRole.assistant &&
                          m.toolCard == null &&
                          m.text.trim() == item.text.trim())),
            )
          : item.confirmation != null
          ? durable.any((m) => m.confirmation != null && sameTool(m))
          : item.toolCard != null && item.toolCard!.toolName != 'showOptions'
          ? [...durable, ...temporary].any(
              (m) =>
                  m.toolCard == null &&
                  sameTool(m) &&
                  (m.questions != null ||
                      m.questionSourceText != null ||
                      m.options.isNotEmpty ||
                      m.confirmation != null ||
                      m.batchConfirmation != null ||
                      m.receipt != null ||
                      m.batchReceipt != null ||
                      m.artifact != null),
            )
          : item.batchConfirmation != null
          ? durable.any(
              (m) =>
                  m.batchConfirmation?.snapshotId ==
                  item.batchConfirmation!.snapshotId,
            )
          : item.options.isNotEmpty
          ? durable.any((m) => m.options.isNotEmpty && sameTool(m))
          : item.document != null
          ? durable.any((m) => m.document?.batchId == item.document!.batchId)
          : item.artifact != null
          ? false
          : durable.any(
              (m) =>
                  item.commandId != null &&
                  m.commandId == item.commandId &&
                  !ConversationLiveMessages.isMemoryNotice(m) &&
                  m.role == item.role &&
                  ConversationMessagePresentation.isPlain(m) &&
                  ((item.toolCallId?.isNotEmpty ?? false)
                      ? sameTool(m) && m.text.trim() == item.text.trim()
                      : (m.toolCallId?.isEmpty ?? true)),
            );
      if (replaced) continue;
      // A not-yet-committed user message still precedes its assistant facts.
      final index = item.commandId == null
          ? -1
          : item.role == MessageRole.user
          ? visible.indexWhere((m) => m.commandId == item.commandId)
          : visible.lastIndexWhere((m) => m.commandId == item.commandId);
      final following = index < 0
          ? _followingTurnIndex(visible, durable, temporary, temporaryIndex)
          : -1;
      final nextOwned =
          item.role == MessageRole.assistant &&
              temporary
                  .take(temporaryIndex)
                  .any(
                    (prior) =>
                        prior.commandId == item.commandId &&
                        ConversationLiveMessages.isMemoryNotice(prior),
                  )
          ? _followingOwnedMessageIndex(
              visible,
              temporary,
              temporaryIndex,
              item.commandId,
            )
          : -1;
      visible.insert(
        nextOwned >= 0
            ? nextOwned
            : index < 0
            ? following < 0
                  ? visible.length
                  : following
            : item.role == MessageRole.user
            ? index
            : index + 1,
        item,
      );
    }
    final projected = BatchArtifactPresentation.project(
      ConversationMessagePresentation.project(visible),
    );
    if (configuredDiagnosticLogLevel == DiagnosticLogLevel.debug) {
      _trace(
        'phase=output count=${projected.length} '
        'ids=${projected.map((item) => item.id).join(',')}',
      );
    }
    return projected;
  }

  /// Initial-opening facts represent parts of the local selection sequence.
  /// Reconcile them in that sequence, before the first submitted task turn.
  /// Matching text in a later task reply must never own a prelude record.
  static void _mergeApologyPrelude(
    List<ConversationMessage> visible,
    List<ConversationMessage> durable,
    List<ConversationMessage> temporary,
    ConversationMessage item,
    String anchor,
    Map<String, String> owners,
  ) {
    final opening = durable.where(
      (m) => m.commandId?.startsWith('initial-opening:') == true,
    );
    final candidate = opening
        .where((m) => m.role == item.role && m.text.trim() == item.text.trim())
        .firstOrNull;
    // The opening payload records the latest selection, not every earlier
    // operation with identical text. Only that local record may be reconciled.
    final localOwner = candidate == null
        ? null
        : temporary
              .where(
                (m) =>
                    m.id.startsWith('local:apology:') &&
                    m.insertBeforeCommandId == anchor &&
                    m.options.isEmpty &&
                    m.role == candidate.role &&
                    m.text.trim() == candidate.text.trim(),
              )
              .lastOrNull;
    final owner = item.options.isEmpty
        ? localOwner?.id == item.id
              ? candidate
              : null
        : owners[anchor] == candidate?.id
        ? candidate
        : null;
    if (owner != null && item.options.isEmpty) {
      owners[anchor] = owner.id;
      return;
    }
    final previous = visible.indexWhere((m) => m.id == owners[anchor]);
    final openingIndex = visible.indexWhere(
      (m) => m.commandId?.startsWith('initial-opening:') == true,
    );
    final commandIndex = visible.indexWhere((m) => m.commandId == anchor);
    final index = owner != null
        ? visible.indexWhere((m) => m.id == owner.id) + 1
        : previous >= 0
        ? previous + 1
        : openingIndex >= 0
        ? openingIndex
        : commandIndex >= 0
        ? commandIndex
        : visible.length;
    visible.insert(index, item);
    owners[anchor] = item.id;
  }

  static void _trace(String message) {
    assert(() {
      if (configuredDiagnosticLogLevel != DiagnosticLogLevel.debug) return true;
      developer.log('[conversation-merge] $message', name: 'phone_agent');
      return true;
    }());
  }

  static String _messageTrace(ConversationMessage message) =>
      'id=${message.id} command=${message.commandId ?? ''} '
      'role=${message.role.name} tool=${message.toolCard?.toolName ?? ''} '
      'toolCall=${message.toolCallId ?? ''} options=${message.options.length} '
      'thinkingLen=${message.thinking?.toString().length ?? 0} textLen=${message.text.length}';

  static int _followingTurnIndex(
    List<ConversationMessage> visible,
    List<ConversationMessage> durable,
    List<ConversationMessage> temporary,
    int position,
  ) {
    for (final later in temporary.skip(position + 1)) {
      final command = later.commandId;
      if (command == null || !durable.any((m) => m.commandId == command)) {
        continue;
      }
      return visible.indexWhere((m) => m.commandId == command);
    }
    return -1;
  }

  static int _followingOwnedMessageIndex(
    List<ConversationMessage> visible,
    List<ConversationMessage> temporary,
    int position,
    String? command,
  ) {
    for (final later in temporary.skip(position + 1)) {
      if (later.commandId != command) continue;
      final index = visible.indexWhere(
        (m) =>
            m.id == later.id ||
            (m.commandId == command &&
                m.toolCallId != null &&
                m.toolCallId == later.toolCallId &&
                ((m.confirmation != null && later.confirmation != null) ||
                    (m.questions != null && later.questions != null) ||
                    m.text.trim() == later.text.trim())),
      );
      if (index >= 0) return index;
    }
    return -1;
  }

  static bool _authoritativeMatch(
    ConversationMessage fact,
    ConversationMessage temporary,
  ) {
    if (temporary.transient != true ||
        fact.role != temporary.role ||
        fact.commandId == null ||
        fact.commandId != temporary.commandId) {
      return false;
    }
    // A committed text fact does not own an interactive card. Only plain
    // assistant text can replace plain live text; card identity is handled by
    // the structured merge below.
    if (fact.role == MessageRole.assistant &&
        (!ConversationMessagePresentation.isPlain(fact) ||
            !ConversationMessagePresentation.isPlain(temporary))) {
      return false;
    }
    final factTool = fact.toolCallId?.trim() ?? '';
    final liveTool = temporary.toolCallId?.trim() ?? '';
    if (ConversationLiveMessages.isMemoryNotice(fact) ||
        ConversationLiveMessages.isMemoryNotice(temporary)) {
      return ConversationLiveMessages.isMemoryNotice(fact) &&
          ConversationLiveMessages.isMemoryNotice(temporary) &&
          fact.text.trim() == temporary.text.trim();
    }
    if (factTool.isNotEmpty || liveTool.isNotEmpty) {
      return factTool.isNotEmpty &&
          factTool == liveTool &&
          fact.text.trim() == temporary.text.trim();
    }
    return fact.role == MessageRole.user ||
        (fact.role == MessageRole.assistant &&
            temporary.confirmation == null &&
            temporary.batchConfirmation == null &&
            temporary.toolCard == null &&
            temporary.receipt == null &&
            temporary.batchReceipt == null);
  }
}
