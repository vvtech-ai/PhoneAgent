import 'package:flutter/material.dart';
import 'package:phone_agent/features/attachments/domain/user_document_presentation.dart';
import 'package:phone_agent/features/attachments/presentation/widgets/native_document_card.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_conversation_background.dart';

/// Actual card; local display toggle only, no document or service ports.
class FlutterDocumentReference extends StatefulWidget {
  const FlutterDocumentReference({super.key});
  @override
  State<FlutterDocumentReference> createState() => _DocumentState();
}

class _DocumentState extends State<FlutterDocumentReference> {
  bool _parsing = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: NativeConversationBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 200, 18, 0),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              NativeDocumentCard(
                parsing: _parsing,
                files: const [
                  UserDocumentFile('合成任务资料.docx', charCount: 120),
                  UserDocumentFile(
                    '合成迁移演练用联系人与参会时间安排清单.xlsx',
                    charCount: 40,
                    truncated: true,
                  ),
                ],
              ),
              TextButton(
                onPressed: () => setState(() => _parsing = !_parsing),
                child: const Text('切换上传状态示例'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
