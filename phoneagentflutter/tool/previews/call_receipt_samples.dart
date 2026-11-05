import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_receipt.dart';

// Entirely synthetic; no real phone numbers, billing or conversation history.
List<ConversationMessage> callReceiptSamples() => [
  for (final (id, outcome, headline) in const [
    ('success', 'SUCCESS', '合成样例：已确认座位'),
    ('failure', 'FAILED', '合成样例：无空位'),
    ('unclear', 'UNCLEAR', '合成样例：尚无明确结论'),
  ])
    ConversationMessage(
      id: id,
      role: MessageRole.assistant,
      text: '',
      receipt: CallReceipt.fromResult({
        'status': 'COMPLETED',
        'headline': headline,
        'metadata': {
          'callAttemptId': id,
          'agentOutcome': outcome,
          'targetName': '合成餐厅',
          'dialogueTranscript': 'AI：这是离线样例。\n商家：没有真实通话。',
        },
        'receiptFields': [
          {'key': 'party', 'label': '人数', 'value': '三人'},
        ],
        'billingSummary': {
          'billingSessionId': 'synthetic:$id',
          'displayDurationSeconds': 12,
          'firstMinutePoints': 5,
          'blockDurationMs': 10000,
          'blockPoints': 2,
          'chargedPoints': 5,
          'remainingPoints': 12345,
        },
      }),
    ),
  ConversationMessage(
    id: 'batch-result',
    role: MessageRole.assistant,
    text: '',
    batchReceipt: BatchReceipt.fromJson({
      'batchId': 'synthetic-batch',
      'status': 'COMPLETED',
      'headline': '合成批量结果，不包含真实外呼',
      'totalCount': 3,
      'items': [
        {
          'itemId': 'a',
          'targetName': '合成甲',
          'status': 'SUCCESS',
          'headline': '已通知',
        },
        {
          'itemId': 'b',
          'targetName': '合成乙',
          'status': 'FAILED',
          'headline': '未接听',
        },
        {
          'itemId': 'c',
          'targetName': '合成丙',
          'status': 'UNCLEAR',
          'headline': '尚待确认',
        },
      ],
    }, fallbackId: 'synthetic-batch'),
  ),
];
