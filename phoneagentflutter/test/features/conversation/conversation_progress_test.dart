import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/call_confirmation.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/conversation_progress.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_receipt.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt.dart';

void main() {
  ConversationProgress stage(
    List<ConversationMessage> messages, {
    bool processing = false,
    bool options = false,
  }) => ConversationProgressPolicy.resolve(
    messages,
    processing: processing,
    hasActiveOptions: options,
  );
  const user = ConversationMessage(
    id: 'user',
    role: MessageRole.user,
    text: '任务已完成，正在通话，补全',
  );
  final confirmation = ConversationMessage(
    id: 'confirmation',
    role: MessageRole.assistant,
    text: '',
    confirmation: CallConfirmation.fromPayload({'targetName': '合成目标'}),
  );
  ConversationMessage single(String status) => ConversationMessage(
    id: 'single',
    role: MessageRole.assistant,
    text: '',
    receipt: CallReceipt(attemptId: 'synthetic', status: status),
  );
  ConversationMessage batch(String status) => ConversationMessage(
    id: 'batch',
    role: MessageRole.assistant,
    text: '',
    batchReceipt: BatchReceipt.fromJson({'status': status}, fallbackId: 'mock'),
  );

  test('empty, user text and processing alone remain first stage', () {
    expect(stage([]), ConversationProgress.instruction);
    expect(stage([user], processing: true), ConversationProgress.instruction);
    expect(stage([user]), ConversationProgress.instruction);
  });
  test('current candidates and v65 assistant clarification markers', () {
    expect(stage([], options: true), ConversationProgress.clarification);
    expect(
      stage([
        const ConversationMessage(
          id: 'ask',
          role: MessageRole.assistant,
          text: '请补全信息',
        ),
      ]),
      ConversationProgress.clarification,
    );
  });
  test(
    'pending call request means execution phase, not a dialing side effect',
    () {
      expect(stage([user, confirmation]), ConversationProgress.execution);
      expect(
        stage([confirmation, user], processing: true),
        ConversationProgress.instruction,
      );
    },
  );
  test('single and batch running receipts map to execution', () {
    expect(stage([single('RUNNING')]), ConversationProgress.execution);
    expect(stage([batch('running')]), ConversationProgress.execution);
  });
  for (final status in ['COMPLETED', 'FAILED', 'CANCELLED']) {
    test('$status is a result stage, not necessarily business success', () {
      expect(stage([single(status)]), ConversationProgress.result);
      expect(stage([batch(status)]), ConversationProgress.result);
    });
  }
  test('old terminal single/batch does not pin a new processing turn', () {
    for (final old in [single('FAILED'), batch('COMPLETED')]) {
      expect(
        stage([old, user], processing: true),
        ConversationProgress.instruction,
      );
      expect(stage([old]), ConversationProgress.result);
    }
  });
  test('current explicit result wins even before stream done', () {
    expect(
      stage([user, single('FAILED')], processing: true),
      ConversationProgress.result,
    );
    expect(
      stage([user, batch('COMPLETED')], processing: true),
      ConversationProgress.result,
    );
  });
  test('result precedence over execution and clarification matches v65', () {
    expect(
      stage([confirmation, batch('COMPLETED')], options: true),
      ConversationProgress.result,
    );
    expect(
      stage([confirmation], options: true),
      ConversationProgress.execution,
    );
  });
}
