import 'dart:convert';
import '../../domain/agent_protocol.dart';
import '../../domain/membership_denial_reply.dart';
import '../history/api_timeline_source.dart';
import 'sse_frame_decoder.dart';

class AgentEventDecoder {
  const AgentEventDecoder();
  AgentEvent decode(SseFrame frame) {
    if (frame.event == 'done') return const AgentEvent(AgentEventKind.done);
    if (frame.event == 'heartbeat') {
      return const AgentEvent(AgentEventKind.heartbeat);
    }
    final Object? value;
    try {
      value = jsonDecode(frame.data);
    } catch (_) {
      throw const FormatException('Invalid Agent JSON');
    }
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid Agent object');
    }
    final root = value;
    final data = root['data'] is Map<String, dynamic>
        ? root['data'] as Map<String, dynamic>
        : <String, dynamic>{};
    String text(Map<String, dynamic> map, String key) =>
        map[key] is String ? map[key] as String : '';
    final session = text(root, 'sessionId'),
        display = text(root, 'displayMessage');
    AgentEvent event(
      AgentEventKind kind, {
      String? message,
      Map<String, dynamic>? payload,
    }) => AgentEvent(
      kind,
      text: message ?? display,
      sessionId: session,
      eventName: frame.event,
      payload: Map.unmodifiable({
        for (final key in [
          'commandId',
          'callId',
          'callAttemptId',
          'outcomePush',
        ])
          if (root.containsKey(key)) key: root[key],
        ...(payload ?? data),
      }),
    );
    AgentEvent signal(String type) => event(
      AgentEventKind.signal,
      payload: {...data, 'type': type, 'sessionId': session, 'text': display},
    );
    switch (frame.event) {
      case 'timeline_committed':
        final ledger = ApiTimelineSource.event(root['data'] ?? root);
        return AgentEvent(
          AgentEventKind.committed,
          sessionId: ledger.sessionId,
          ledger: ledger,
        );
      case 'text_delta':
        return event(
          AgentEventKind.text,
          message: text(root, 'text'),
          payload: root,
        );
      case 'thinking_delta':
        return event(
          AgentEventKind.thinking,
          message: text(data.containsKey('text') ? data : root, 'text'),
          payload: {
            ...root,
            ...data,
            'append': true,
            'start': (data['start'] ?? root['start']) == true,
          },
        );
      case 'thinking_done':
        return event(AgentEventKind.thinkingDone, payload: {...root, ...data});
      case 'memory_notice':
        final notice = text(data, 'text').trim().isNotEmpty
            ? text(data, 'text').trim()
            : display.trim();
        return event(
          notice.isEmpty ? AgentEventKind.unknown : AgentEventKind.status,
          message: notice,
          payload: {...data, 'type': 'MEMORY_NOTICE'},
        );
      case 'tool_call_start':
        return event(AgentEventKind.toolStart, payload: root);
      case 'tool_call_complete':
        return event(AgentEventKind.toolComplete, payload: root);
      case 'signal':
        return event(
          AgentEventKind.signal,
          message: text(root, 'text'),
          payload: root,
        );
      case 'final':
        return event(
          AgentEventKind.finalResponse,
          message: text(root, 'text'),
          payload: root,
        );
      case 'error':
        return event(AgentEventKind.error, message: text(root, 'message'));
      case 'tool_card':
        return event(
          AgentEventKind.toolCard,
          payload: {
            ...data,
            'methodLabel': text(data, 'methodLabel').isNotEmpty
                ? text(data, 'methodLabel')
                : text(data, 'toolName'),
            'result': text(data, 'result').isNotEmpty
                ? text(data, 'result')
                : display,
          },
        );
      case 'scene_detected':
      case 'search_started':
      case 'search_result_ready':
      case 'pre_call_checking':
        return event(AgentEventKind.thinking);
      case 'task_cancelled':
      case 'call_started':
      case 'call_status_changed':
      case 'call_finished':
      case 'call_outcome_preview':
        return event(AgentEventKind.status);
      case 'slot_updated':
        final message = text(data, 'text').isNotEmpty
            ? text(data, 'text')
            : display;
        return event(
          data['progressOnly'] == true ||
                  data['primaryClosed'] == true ||
                  data['dialFailureObserved'] == true ||
                  message.isEmpty
              ? AgentEventKind.status
              : AgentEventKind.finalResponse,
          message: message,
          payload: {...data, 'type': 'TEXT_REPLY'},
        );
      case 'ask_user':
        return signal('ASK_USER');
      case 'options_available':
        return signal('SHOW_OPTIONS');
      case 'request_permission':
        return signal('REQUEST_PERMISSION');
      case 'import_document_request':
        return signal('IMPORT_DOCUMENT_REQUEST');
      case 'call_ready':
        return signal('MAKE_CALL_REQUEST');
      case 'lookup_contact_request':
      case 'agent_lookup_contact':
        return signal('LOOKUP_CONTACT_REQUEST');
      case 'agent_lookup_device_contacts_by_names':
        return signal('LOOKUP_DEVICE_CONTACTS_BY_NAMES_REQUEST');
      case 'task_completed':
      case 'task_outcome_unclear':
      case 'task_failed':
        if (frame.event == 'task_failed' &&
            data['callResult'] == null &&
            data['batchCallResult'] == null) {
          final denial = MembershipDenialReply.message(
            data['errorCode'] ?? data['code'],
          );
          if (denial != null) {
            return event(
              AgentEventKind.finalResponse,
              message: denial,
              payload: {...data, 'type': 'TEXT_REPLY'},
            );
          }
          return event(AgentEventKind.error);
        }
        return event(
          AgentEventKind.finalResponse,
          payload: {
            ...data,
            'type': data['batchCallResult'] != null
                ? 'BATCH_CALL_RESULT'
                : data['callResult'] != null
                ? 'CALL_RESULT'
                : 'TEXT_REPLY',
          },
        );
      default:
        return event(AgentEventKind.unknown, payload: root);
    }
  }
}
