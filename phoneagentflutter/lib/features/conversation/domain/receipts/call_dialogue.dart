enum CallDialogueRole { assistant, remote }

class CallDialogueLine {
  const CallDialogueLine(this.role, this.text);
  final CallDialogueRole role;
  final String text;
}

/// v65 AgentStreamCallTranscriptPolicy: recognized speakers only, preserve
/// repeated utterances. Unknown labels/summary notes are not spoken dialogue.
abstract final class CallDialogue {
  static List<CallDialogueLine> parse(String text) {
    final result = <CallDialogueLine>[];
    for (final line in text.split('\n').map((s) => s.trim())) {
      final delimiter = RegExp('[:：]').firstMatch(line)?.start ?? -1;
      if (delimiter <= 0) continue;
      var speaker = line.substring(0, delimiter).trim();
      for (final pair in const [('[', ']'), ('【', '】')]) {
        if (speaker.startsWith(pair.$1) && speaker.endsWith(pair.$2)) {
          speaker = speaker.substring(1, speaker.length - 1);
        }
      }
      final role = switch (speaker.toLowerCase()) {
        'assistant' ||
        'ai' ||
        'a.i.' ||
        'chaken.ai' ||
        'ai助理' ||
        '助手' ||
        '智能助理' ||
        '机器人' => CallDialogueRole.assistant,
        'callee' ||
        'merchant' ||
        'remote' ||
        'shop' ||
        'store' ||
        'restaurant' ||
        '对方' ||
        '商家' ||
        '店员' ||
        '餐厅' ||
        '被叫' ||
        '接听方' ||
        '联系人' ||
        '客户' => CallDialogueRole.remote,
        _ => null,
      };
      final content = line.substring(delimiter + 1).trim();
      if (role != null && content.isNotEmpty) {
        result.add(CallDialogueLine(role, content));
      }
    }
    return List.unmodifiable(result);
  }
}
