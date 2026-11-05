import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/data/stream/agent_event_decoder.dart';
import 'package:phone_agent/features/conversation/data/stream/sse_frame_decoder.dart';
import 'package:phone_agent/features/conversation/domain/agent_failure.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_failure_presentation.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';

void main() {
  for (final type in ['error', 'task_failed']) {
    test('$type keeps structured failure contract through decoder', () {
      final event = const AgentEventDecoder().decode(
        SseFrame(
          type,
          jsonEncode({
            'sessionId': 'synthetic-session',
            'message': 'synthetic diagnostic',
            'displayMessage': 'synthetic diagnostic',
            'data': {
              'errorCode': 'MODEL_TIMEOUT',
              'category': 'MODEL',
              'retryable': true,
              'recoveryAction': 'RETRY',
              'traceId': 'synthetic-trace',
              'stage': 'MODEL_EXECUTION',
            },
          }),
        ),
      );
      final failure = AgentFailure.fromEvent(event);
      expect(event.kind, AgentEventKind.error);
      expect(failure.errorCode, 'MODEL_TIMEOUT');
      expect(failure.category, 'MODEL');
      expect(failure.retryable, isTrue);
      expect(failure.recoveryAction, 'RETRY');
      expect(failure.traceId, 'synthetic-trace');
      expect(failure.stage, 'MODEL_EXECUTION');
      expect(failure.message, 'synthetic diagnostic');
      expect(failure.isNetworkFailure, isFalse);
      expect(failure.toString(), 'AgentFailure(redacted)');
    });
  }
  test('structured classification overrides contradictory message', () {
    expect(
      const AgentFailure(category: 'model', message: '网络连接异常').isNetworkFailure,
      isFalse,
    );
    expect(
      const AgentFailure(category: 'network', message: '额度不足').isNetworkFailure,
      isTrue,
    );
    expect(
      const AgentFailure(errorCode: 'network_transport').isNetworkFailure,
      isTrue,
    );
    expect(
      const AgentFailure(
        errorCode: 'MODEL_TIMEOUT',
        message: 'SocketTimeout',
      ).isNetworkFailure,
      isFalse,
    );
  });
  for (final message in [
    'HTTP 408',
    'SocketTimeoutException',
    'connection reset',
    '域名解析失败',
  ]) {
    test('legacy $message is transport interruption', () {
      expect(AgentFailure(message: message).isNetworkFailure, isTrue);
    });
  }
  for (final message in ['HTTP 503', 'HTTP 429', 'model timeout', '服务响应超时']) {
    test('legacy $message is not proof of device disconnection', () {
      expect(AgentFailure(message: message).isNetworkFailure, isFalse);
    });
  }
  test('malformed optional fields are not coerced into recovery authority', () {
    final failure = AgentFailure.fromEvent(
      const AgentEvent(
        AgentEventKind.error,
        payload: {
          'errorCode': ['NETWORK_TRANSPORT'],
          'category': 1,
          'retryable': 'true',
        },
      ),
    );
    expect(failure.hasStructuredFailure, isFalse);
    expect(failure.retryable, isNull);
  });
  test(
    'presentation never exposes raw endpoint, trace or diagnostic message',
    () {
      const initial = ConversationState(
        entry: ConversationEntry(sessionId: 's'),
      );
      const failure = AgentFailure(
        errorCode: 'MODEL_TIMEOUT',
        category: 'MODEL',
        message: 'https://private.example.test?token=synthetic-secret',
        traceId: 'private-trace',
      );
      final result = ConversationFailurePresentation.apply(
        initial,
        failure,
        hasActiveCall: false,
      );
      expect(result.notice, '服务响应超时，请稍后重试');
      expect(result.phase, ConversationPhase.ready);
      expect(result.notice, isNot(contains('private')));
      final active = ConversationFailurePresentation.apply(
        initial,
        failure,
        hasActiveCall: true,
      );
      expect(active.phase, ConversationPhase.recoveryRequired);
      expect(active.notice, contains('正在确认通话状态'));
    },
  );

  test('phone capacity failure returns to ready with a fixed message', () {
    const initial = ConversationState(
      entry: ConversationEntry(sessionId: 's'),
      phase: ConversationPhase.sending,
      activity: '正在思考…',
    );
    const failure = AgentFailure(
      errorCode: 'PHONE_CAPACITY_UNAVAILABLE',
      category: 'CALL',
      message: '线路仍忙，再试一次',
    );
    final result = ConversationFailurePresentation.apply(
      initial,
      failure,
      hasActiveCall: false,
    );
    expect(result.phase, ConversationPhase.ready);
    expect(result.activity, isEmpty);
    expect(result.notice, '电话线路正忙，本次未拨出，请稍后重试');
  });

  test('business and points failures keep their own feedback', () {
    const initial = ConversationState(entry: ConversationEntry(sessionId: 's'));
    for (final entry in {
      'BUSINESS_REJECTED': '本次操作未完成',
      'POINTS_INSUFFICIENT_BALANCE': '积分不足',
    }.entries) {
      final state = ConversationFailurePresentation.apply(
        initial,
        AgentFailure(
          errorCode: entry.key,
          category: 'BUSINESS',
          message: 'private',
        ),
        hasActiveCall: false,
      );
      expect(state.notice, contains(entry.value));
      expect(state.notice, isNot(contains('private')));
    }
  });
}
