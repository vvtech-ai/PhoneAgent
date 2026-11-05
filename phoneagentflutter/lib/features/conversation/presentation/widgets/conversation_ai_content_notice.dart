import 'package:flutter/material.dart';

import '../../../../core/design/conversation_tokens.dart';

class ConversationAiContentNotice extends StatelessWidget {
  const ConversationAiContentNotice({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: Text(
      '内容由AI生成',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12, color: ConversationTokens.subtitle),
    ),
  );
}
