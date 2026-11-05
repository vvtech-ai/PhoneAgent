import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/attachments/domain/user_document_presentation.dart';
import 'package:phone_agent/features/conversation/domain/artifacts/task_artifact.dart';
import 'package:phone_agent/features/conversation/domain/conversation_live_messages.dart';
import 'package:phone_agent/features/conversation/domain/conversation_message_merge.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/conversation_questions.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/call_confirmation.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_message_store.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_presentation_projection.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';

ConversationMessage message(
  String id, {
  String command = 'c',
  String? tool,
  String text = '合成问题',
  MessageRole role = MessageRole.assistant,
  bool options = false,
  bool question = false,
  TaskArtifact? artifact,
}) => ConversationMessage(
  id: id,
  role: role,
  text: text,
  commandId: command,
  toolCallId: tool,
  options: options ? const [ConversationOption('合成候选', '')] : const [],
  questions: question
      ? ConversationQuestions.parse({
          'title': '合成问题',
          'items': [
            {'id': 'q', 'prompt': '合成问题', 'answerType': 'text'},
          ],
        })
      : null,
  artifact: artifact,
);

const artifact = TaskArtifact(
  id: 'skill-template:synthetic:v1',
  kind: TaskArtifactKind.template,
  fileName: '合成模板.docx',
  mimeType:
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  status: 'READY',
);

LedgerEvent fact(
  int sequence,
  String type,
  Map<String, Object?> payload, {
  String command = 'c',
}) => LedgerEvent(
  eventId: 'e$sequence',
  sessionId: 's',
  sequence: sequence,
  type: type,
  schemaVersion: 1,
  commandId: command,
  payload: payload,
);

void main() {
  test('accepted document replaces only the same transient document batch', () {
    ConversationMessage document(String id, String batch) =>
        ConversationMessage(
          id: id,
          role: MessageRole.user,
          text: '合成文档',
          commandId: 'c',
          document: UserDocumentPresentation(batch, const [
            UserDocumentFile('合成.docx'),
          ]),
        );
    final durable = document('durable', 'first');
    expect(
      ConversationMessageMerge.merge([durable], [document('live', 'first')]),
      [durable],
    );
    expect(
      ConversationMessageMerge.merge([durable], [document('other', 'second')]),
      hasLength(2),
    );
  });

  test(
    'confirmation suppresses same pending tool trace across reply commands',
    () {
      final confirmation = ConversationMessage(
        id: 'confirmation',
        role: MessageRole.assistant,
        text: '',
        commandId: 'old',
        toolCallId: 'pending',
        confirmation: CallConfirmation.fromPayload({'targetName': '合成目标'}),
      );
      expect(
        ConversationMessageMerge.merge(
          [confirmation],
          [
            ConversationLiveMessages.toolCard('c', {
              'toolName': 'makeCall',
              'toolCallId': 'pending',
            }),
          ],
        ),
        [confirmation],
      );
    },
  );

  test('consecutive interactive tools and later text retain prior cards', () {
    final store = ConversationMessageStore();
    var state = const ConversationState(
      entry: ConversationEntry(sessionId: 's'),
    );
    for (final tool in ['first', 'second']) {
      state = store.interactive(
        state,
        'c',
        const AgentEvent(
          AgentEventKind.signal,
          payload: {
            'type': 'SHOW_OPTIONS',
            'options': {
              'items': [
                {'label': '合成候选'},
              ],
            },
          },
        ),
        tool,
      );
    }
    final active = state.activeOptionsId;
    store.assistant('c', '独立合成回复', const [], null);
    state = store.project(state);
    expect(state.messages.where((m) => m.options.isNotEmpty), hasLength(2));
    expect(state.messages.last.text, '独立合成回复');
    expect(state.activeOptionsId, active);
    expect(
      state.messages.singleWhere((m) => m.id == active).toolCallId,
      'second',
    );
  });

  test(
    'different live question tools do not overwrite each other or prose',
    () {
      final store = ConversationMessageStore();
      var state = const ConversationState(
        entry: ConversationEntry(sessionId: 's'),
      );
      store.assistant('c', '独立合成正文', const [], null);
      for (final tool in ['first', 'second']) {
        state = store.interactive(
          state,
          'c',
          const AgentEvent(
            AgentEventKind.signal,
            payload: {
              'type': 'ASK_USER',
              'questions': {'title': '合成补问'},
            },
          ),
          tool,
        );
      }
      expect(state.messages.map((m) => m.text), ['独立合成正文', '合成补问', '合成补问']);
    },
  );

  test('structured prompt suppresses equal prose only in its own command', () {
    final store = ConversationMessageStore();
    store.upsert(message('card', tool: 'ask', question: true));
    store.upsert(message('echo'));
    store.upsert(message('next', command: 'next'));
    const state = ConversationState(entry: ConversationEntry(sessionId: 's'));
    expect(store.project(state).messages.map((m) => m.id), ['card', 'next']);
  });

  test('durable question cannot swallow independent streaming text', () {
    final live = message('live', text: '先为你查找合成资料');
    expect(
      ConversationMessageMerge.merge(
        [message('question', tool: 'ask', question: true)],
        [live],
      ).map((m) => m.id),
      ['question', 'live'],
    );
  });

  test('different option tools in one command remain separate', () {
    expect(
      ConversationMessageMerge.merge(
        [message('first', tool: 'first', options: true)],
        [message('second', tool: 'second', options: true)],
      ).map((m) => m.id),
      ['first', 'second'],
    );
  });

  test('same option tool reconciles once and keeps durable contents', () {
    expect(
      ConversationMessageMerge.merge(
        [message('durable', tool: 'choice', options: true)],
        [message('live', tool: 'choice', options: true)],
      ).single.id,
      'durable',
    );
  });

  test('late artifact stays with its command before next user turn', () {
    expect(
      ConversationMessageMerge.merge(
        [
          message('first'),
          message('next', command: 'next', role: MessageRole.user),
        ],
        [message('file', text: '', artifact: artifact)],
      ).map((m) => m.id),
      ['first', 'file', 'next'],
    );
  });

  test('template card suppresses its tool trace while streaming', () {
    expect(
      ConversationMessageMerge.merge([], [
        ConversationLiveMessages.toolCard('c', {
          'toolName': 'provideSkillTemplate',
          'toolCallId': 'template',
        }),
        message('file', text: '', artifact: artifact),
      ]).map((m) => m.id),
      ['file'],
    );
  });

  test('repeated artifact facts update in place before later user turn', () {
    const payload = {
      'artifact': {
        'artifactId': 'skill-template:synthetic:v1',
        'kind': 'SKILL_TEMPLATE',
        'fileName': '合成模板.docx',
        'mimeType':
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'status': 'READY',
      },
    };
    final messages = ConversationMessages.project([
      fact(1, 'TOOL_RESULT_RECORDED', payload),
      fact(2, 'USER_TURN_ACCEPTED', {'text': '下一轮合成输入'}, command: 'next'),
      fact(3, 'TOOL_RESULT_RECORDED', payload),
    ]);
    expect(messages.first.artifact?.id, artifact.id);
    expect(messages.last.role, MessageRole.user);
  });

  test('same tool repeated facts dedupe in both live and restore', () {
    const payload = {
      'toolName': 'showOptions',
      'toolCallId': 'choice',
      'displayPayloadVersion': 1,
      'arguments': {
        'title': '合成候选',
        'items': [
          {'label': '合成餐厅'},
        ],
      },
    };
    final facts = [
      fact(1, 'TOOL_REQUESTED', payload),
      fact(2, 'TOOL_REQUESTED', payload),
    ];
    const state = ConversationState(entry: ConversationEntry(sessionId: 's'));
    final store = ConversationMessageStore();
    for (final event in facts) {
      store.facts[event.eventId] = event;
    }
    expect(store.project(state).messages, hasLength(1));
    final restored = ConversationPresentationProjection.restore(
      state,
      RestoredConversation(
        const ConversationDetail(sessionId: 's', title: '', status: 'ACTIVE'),
        ledger: LedgerSnapshot(
          's',
          2,
          const LedgerProjection(
            status: 'ACTIVE',
            continuable: true,
            pendingRestorable: false,
            migrationStatus: 'NATIVE',
            projectedThrough: 2,
          ),
          facts,
        ),
      ),
    );
    expect(restored.messages, hasLength(1));
  });

  test('tool finish removes progress and keeps interactive cards', () {
    final store = ConversationMessageStore();
    for (final name in [
      'search',
      'askUser',
      'showOptions',
      'importDocument',
      'requestPermission',
    ]) {
      store.upsert(ConversationLiveMessages.toolCard('c', {'toolName': name}));
    }
    store.finishTools(commandId: 'c');
    expect(store.messages.map((m) => m.toolCard!.toolName), [
      'askUser',
      'showOptions',
      'importDocument',
      'requestPermission',
    ]);
  });
}
