import 'package:flutter/material.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_receipt.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/receipts/batch_receipt_card.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_conversation_background.dart';

/// Same local fixture as the actual native item; no audio or service ports.
class FlutterBatchResultReference extends StatelessWidget {
  const FlutterBatchResultReference({super.key, this.withTranscript = false});
  final bool withTranscript;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: NativeConversationBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 200, 18, 0),
          child: Align(
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
                      if (withTranscript) 'transcript': 'assistant: 合成询问\ncallee: 合成答复',
                      'receiptFields': [
                        {
                          'key': 'businessResult',
                          'label': '业务结果',
                          'value': '确认参加',
                        },
                        {'key': 'purpose', 'label': '事项', 'value': '合成评审'},
                      ],
                    }, 'synthetic-result'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
