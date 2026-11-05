import 'dart:async';
import '../flutter_options_reference.dart';
import '../flutter_options_timeline_reference.dart';
import '../flutter_tasks_scroll_reference.dart';
import 'package:phone_agent/features/attachments/domain/user_document_presentation.dart';
import 'package:phone_agent/features/attachments/presentation/widgets/native_document_card.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_receipt.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/receipts/batch_receipt_card.dart';
import 'package:flutter/material.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/batch_confirmation.dart';
import 'package:phone_agent/features/conversation/domain/call_confirmation.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/batch_confirmation_card.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_message_tile.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_conversation_background.dart';

// Actual production widgets; only the host's pure text renderer is registered.
void main() => runApp(
  const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: bool.fromEnvironment('UI_REFERENCE_TASKS_SCROLL')
        ? FlutterTasksScrollReference()
        : bool.fromEnvironment('UI_REFERENCE_OPTIONS_TIMELINE')
        ? FlutterOptionsTimelineReference()
        : bool.fromEnvironment('UI_REFERENCE_OPTIONS')
        ? FlutterOptionsReference()
        : _Reference(),
  ),
);

const _original = bool.fromEnvironment('UI_REFERENCE_SHORT')
    ? '.'
    : '明天晚上六点，三个人。';
const _dynamic = bool.fromEnvironment('UI_REFERENCE_DYNAMIC');

class _Reference extends StatefulWidget {
  const _Reference();
  @override
  State<_Reference> createState() => _ReferenceState();
}

class _ReferenceState extends State<_Reference> {
  String _text = _original;
  bool _closed = false;
  Timer? _stream;

  void _append() {
    _stream?.cancel();
    var tick = 0;
    _stream = Timer.periodic(const Duration(milliseconds: 40), (timer) {
      if (!mounted || _closed) {
        timer.cancel();
        return;
      }
      setState(() => _text = '$_original${'，合成新增要求' * ++tick}');
      if (tick == 12) timer.cancel();
    });
  }

  @override
  void dispose() {
    _stream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: NativeConversationBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 200, 18, 0),
          child: _closed
              ? const Text('参考已关闭')
              : const bool.fromEnvironment('UI_REFERENCE_DOCUMENT')
              ? const Align(
                  alignment: Alignment.topRight,
                  child: SizedBox(
                    width: 308,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        NativeDocumentCard(
                          files: [
                            UserDocumentFile('合成任务资料.docx', charCount: 120),
                            UserDocumentFile(
                              '合成迁移演练用联系人与参会时间安排清单.xlsx',
                              charCount: 40,
                              truncated: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              : const bool.fromEnvironment('UI_REFERENCE_RESULT')
              ? Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 308,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        BatchReceiptItemCard(
                          item: BatchReceiptItem.fromJson({
                            'status': 'SUCCESS',
                            'targetName': '合成联系人',
                            'headline': '合成结果：已完成',
                            if (const bool.fromEnvironment(
                              'UI_REFERENCE_TRANSCRIPT',
                            ))
                              'transcript': 'assistant: 合成询问\ncallee: 合成答复',
                            'receiptFields': [
                              {
                                'key': 'businessResult',
                                'label': '业务结果',
                                'value': '确认参加',
                              },
                              {
                                'key': 'purpose',
                                'label': '事项',
                                'value': '合成评审',
                              },
                            ],
                          }, 'synthetic-result'),
                        ),
                      ],
                    ),
                  ),
                )
              : const bool.fromEnvironment('UI_REFERENCE_BATCH')
              ? const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BatchConfirmationCard(
                      confirmation: BatchConfirmation(
                        snapshotId: 'synthetic-batch',
                        version: 1,
                        title: '',
                        sections: [
                          BatchConfirmationSection('任务信息', [
                            ConfirmationRow('目的', '合成评审'),
                          ]),
                        ],
                        recipients: [
                          BatchConfirmationRecipient(
                            id: 'synthetic-audit',
                            name: '合成联系人',
                            phone: '',
                            salutation: '您好',
                            status: 'READY',
                            detail: 'MOCK · 不拨号',
                          ),
                        ],
                        issues: [ConfirmationRow('合成问题', '未执行')],
                        summary: (original: 6, callable: 5, skipped: 1),
                        rules: [ConfirmationRow('时间', '合成时间')],
                        assistantText: '合成确认说明',
                      ),
                    ),
                    ConversationMessageTile(
                      message: ConversationMessage(
                        id: 'synthetic-batch-tail',
                        role: MessageRole.user,
                        text: '.',
                      ),
                      optionsEnabled: false,
                      onChoose: _ignoreChoice,
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ConversationMessageTile(
                      message: const ConversationMessage(
                        id: 'synthetic-assistant',
                        role: MessageRole.assistant,
                        text: '想订演示联系人？告诉我时间和人数就行，有其他要求也可以一起说。',
                      ),
                      optionsEnabled: false,
                      onChoose: (_) {},
                    ),
                    ConversationMessageTile(
                      message: ConversationMessage(
                        id: 'synthetic-user',
                        role: MessageRole.user,
                        text: _text,
                      ),
                      optionsEnabled: false,
                      onChoose: (_) {},
                    ),
                    if (_dynamic)
                      Wrap(
                        children: [
                          TextButton(
                            onPressed: _append,
                            child: const Text('追加合成文字'),
                          ),
                          TextButton(
                            onPressed: () {
                              _stream?.cancel();
                              setState(() => _text = _original);
                            },
                            child: const Text('恢复合成文字'),
                          ),
                          TextButton(
                            onPressed: () {
                              _stream?.cancel();
                              setState(() => _closed = true);
                            },
                            child: const Text('关闭参考'),
                          ),
                        ],
                      ),
                  ],
                ),
        ),
      ),
    ),
  );
}

void _ignoreChoice(int _) {}
