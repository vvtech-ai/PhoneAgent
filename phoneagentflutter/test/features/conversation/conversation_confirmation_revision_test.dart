import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/batch_confirmation.dart';
import 'package:phone_agent/features/conversation/domain/call_confirmation.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_content_revision.dart';

void main() {
  ConversationContentRevision revision({
    CallConfirmation? single,
    BatchConfirmation? batch,
  }) => ConversationContentRevision('synthetic', [
    ConversationMessage(
      id: 'same',
      role: MessageRole.assistant,
      text: '',
      confirmation: single,
      batchConfirmation: batch,
    ),
  ]);
  CallConfirmation single(String goal, String hidden) => CallConfirmation(
    targetName: '合成目标',
    phoneNumber: '',
    primaryGoal: goal,
    summaryLines: const [],
    sourceSpec: {'hidden': hidden},
  );
  BatchConfirmation batch(
    List<ConfirmationRow> rows, {
    String title = '',
    String assistant = '请补充信息',
    BatchConfirmationDecision decision = BatchConfirmationDecision.pending,
  }) => BatchConfirmation(
    snapshotId: 'synthetic',
    version: 1,
    title: title,
    sections: const [],
    recipients: const [],
    issues: const [],
    rules: rows,
    assistantText: assistant,
    decision: decision,
  );

  test(
    'single display changes and hidden execution fields do not reset history',
    () {
      final old = revision(single: single('合成目的', 'before'));
      expect(revision(single: single('合成目的', 'after')), old);
      expect(revision(single: single('更新目的', 'before')), isNot(old));
      expect(revision(), isNot(old));
    },
  );
  test('batch snapshots freeze rows and ignore non-visible generic text', () {
    final rows = [const ConfirmationRow('规则', '合成规则')];
    final old = revision(batch: batch(rows));
    expect(
      revision(
        batch: batch(
          [const ConfirmationRow('规则', '合成规则')],
          title: '未显示标题',
          assistant: '请语音回答',
        ),
      ),
      old,
    );
    rows[0] = const ConfirmationRow('规则', '更新规则');
    expect(revision(batch: batch(rows)), isNot(old));
    expect(revision(batch: batch([const ConfirmationRow('规则', '合成规则')])), old);
    expect(
      revision(
        batch: batch([
          const ConfirmationRow('规则', '合成规则'),
        ], decision: BatchConfirmationDecision.confirmed),
      ),
      isNot(old),
    );
    expect(
      revision(
        batch: batch([const ConfirmationRow('规则', '合成规则')], assistant: '合成说明'),
      ),
      isNot(old),
    );
  });
}
