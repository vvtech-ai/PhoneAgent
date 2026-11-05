import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';

/// Explicit synthetic askUser fixture; never bound by the production App.
abstract final class ShellQuestionSeed {
  static Map<String, Object?> request(String command) => {
    'modelTurnId': command,
    'toolCallId': 'questions:$command',
    'toolName': 'askUser',
    'ordinal': 0,
    'displayPayloadVersion': 1,
    'arguments': payload,
  };
  static const payload = {
    'title': 'MOCK · 补充需求',
    'items': [
      {'id': 'phone', 'prompt': '电话号码', 'answerType': 'phone'},
      {
        'id': 'choice',
        'prompt': '餐厅类型',
        'answerType': 'single_choice',
        'choices': ['中餐', '西餐'],
      },
      {'id': 'confirm', 'prompt': '是否需要包间', 'answerType': 'confirm'},
    ],
  };
  static AgentEvent signal(String session, String tool) => AgentEvent(
    AgentEventKind.signal,
    sessionId: session,
    payload: {
      'type': 'ASK_USER',
      'pendingToolCallId': tool,
      'questions': payload,
    },
  );
}
