import '../domain/conversation_messages.dart';
import '../domain/receipts/call_receipt.dart';
import '../domain/receipts/batch_receipt.dart';

/// Synthetic fixtures only. No account, network, actual calls or recordings.
List<ConversationMessage> previewReceipts({bool running = false}) => [
  for (final (id, outcome, title) in const [
    ('success', 'SUCCESS', '合成会议：已确认参加'),
    ('failure', 'FAILED', '合成餐厅：无空位'),
    ('unclear', 'UNCLEAR', '合成邀约：尚无明确结论'),
  ])
    ConversationMessage(
      id: 'preview:$id',
      role: MessageRole.assistant,
      text: '',
      receipt: CallReceipt(
        attemptId: 'preview:$id',
        status: 'COMPLETED',
        targetName: '合成联系人',
        headline: title,
        metadata: {'agentOutcome': outcome, 'callId': 'preview-$id'},
        transcript: 'AI：这是离线回执演练。\n对方：没有真实电话。',
        fields: const [ReceiptField('time', '时间', '明天下午三点')],
        billing: ReceiptBilling(
          sessionId: 'preview:$id',
          state: 'SETTLED',
          durationSeconds: 12,
          chargedPoints: 5,
          remainingPoints: 900,
          firstMinutePoints: 5,
          blockDurationMs: 10000,
          blockPoints: 2,
        ),
      ),
    ),
  ConversationMessage(
    id: 'preview:batch',
    role: MessageRole.assistant,
    text: '',
    batchReceipt: BatchReceipt.fromJson({
      'batchId': 'preview:batch',
      'status': running ? 'RUNNING' : 'COMPLETED',
      'totalCount': 3,
      'headline': '合成批量结果，不含真实通话或扣费',
      'items': [
        for (final (id, name, result) in const [
          ('a', '合成甲', 'SUCCESS'),
          ('b', '合成乙', 'FAILED'),
          ('c', '合成丙', 'UNCLEAR'),
        ])
          {
            'itemId': id,
            'callId': 'preview-batch-$id',
            'targetName': name,
            'status': running && id == 'c' ? 'RUNNING' : result,
            'headline': running && id == 'c' ? '结果等待中' : '合成样例：$name',
            'transcript': 'AI：询问$name的安排。\n对方：这是$name的离线记录。',
            'billingSummaries': [
              {
                'billingSessionId': 'preview:bill:$id',
                'displayDurationSeconds': 12,
                'connectedDurationMs': id == 'b' ? 0 : 12000,
                'chargedPoints': 5,
                'remainingPoints': 900,
              },
            ],
          },
      ],
    }, fallbackId: 'preview:batch'),
  ),
];
