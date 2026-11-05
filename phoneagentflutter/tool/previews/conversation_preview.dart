// Run only for deterministic UI verification; never imports account/API wiring.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:phone_agent/features/conversation/domain/call_confirmation.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/conversation_tool_card.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_page.dart';
import 'call_receipt_samples.dart';

void main() {
  if (!kDebugMode) throw UnsupportedError('Preview is debug-only');
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  runApp(const MaterialApp(home: ConversationSamplesPage()));
}

class ConversationSamplesPage extends StatelessWidget {
  const ConversationSamplesPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('离线组件验收，非正式应用'),
          const Text('无登录、无接口、无拨号；仅复用实际 Flutter 组件。'),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const _ConversationPreview(),
              ),
            ),
            child: const Text('打开统一页确认卡样例'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const _ConversationPreview(receipts: true),
              ),
            ),
            child: const Text('打开单路/批量回执文本样例'),
          ),
        ],
      ),
    ),
  );
}

class _ConversationPreview extends StatefulWidget {
  const _ConversationPreview({this.receipts = false});
  final bool receipts;
  @override
  State<_ConversationPreview> createState() => _PreviewState();
}

class _PreviewState extends State<_ConversationPreview> {
  bool voice = true;
  String notice = '';
  late final messages = widget.receipts
      ? callReceiptSamples()
      : <ConversationMessage>[
          const ConversationMessage(
            id: 'u',
            role: MessageRole.user,
            text: '这是合成数据，不拨打电话。',
          ),
          ConversationMessage(
            id: 'tool',
            role: MessageRole.assistant,
            text: '',
            toolCard: ConversationToolCard.fromPayload({
              'toolName': 'search',
              'methodLabel': 'search()',
              'body': 'keyword: "合成餐厅"',
              'result': '合成结果：2 条候选',
            }),
          ),
          ConversationMessage(
            id: 'single',
            role: MessageRole.assistant,
            text: '',
            confirmation: CallConfirmation.fromPayload({
              'targetName': '合成餐厅',
              'phoneNumber': '000',
              'primaryGoal': '询问晚餐座位',
              'summaryLines': ['人数：三人', '时间：19:00'],
            }),
          ),
          ConversationMessage(
            id: 'batch',
            role: MessageRole.assistant,
            text: '',
            confirmation: CallConfirmation.fromPayload({
              'recipientsJson': [
                {'targetName': '合成联系人甲'},
                {'targetName': '合成联系人乙'},
              ],
              'primaryGoal': '演示批量摘要，不发起任务',
            }, batch: true),
          ),
        ];

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFE8ECF2),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                color: const Color(0xFFFFF3CD),
                padding: const EdgeInsets.all(8),
                child: const Text(
                  'MOCK · 合成数据 · 不连接任何服务',
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: ConversationPage(
                  state: ConversationState(
                    entry: const ConversationEntry(
                      sessionId: 'synthetic-preview',
                    ),
                    voiceMode: voice,
                    messages: messages,
                    notice: notice,
                  ),
                  modelName: '合成模型',
                  onClose: () => Navigator.of(context).pop(),
                  onToggle: () => setState(() => voice = !voice),
                  onSend: (text) {
                    setState(() {
                      messages.add(
                        ConversationMessage(
                          id: 'preview:${messages.length}',
                          role: MessageRole.user,
                          text: text,
                        ),
                      );
                      notice = '离线预览未发送网络请求。';
                    });
                    return true;
                  },
                  onChoose: (_, _) => false,
                  onRetry: () {},
                  onNotice: (value) => setState(() => notice = value),
                  onModels: () => setState(() => notice = '预览固定合成模型，不修改账号设置。'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
