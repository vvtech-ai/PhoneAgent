import '../agent_protocol.dart';
import '../conversation_messages.dart';
import '../conversation_questions.dart';
import '../confirmation/call_confirmation_prompt.dart';

class SpeechPromptPolicy {
  static String prompt(AgentEvent event) {
    final data = event.payload;
    final type = ConversationMessages.text(data, 'type');
    Map<String, Object?> object(String key) =>
        ConversationMessages.object(data[key]);
    String value(Map<String, Object?> map, String key) =>
        ConversationMessages.text(map, key);
    switch (type) {
      case 'MAKE_CALL_REQUEST':
        return CallConfirmationPrompt.text;
      case 'TEXT_REPLY':
        return event.kind == AgentEventKind.finalResponse ? event.text : '';
      case 'ASK_USER':
        final questions = ConversationMessages.questionPayload(data);
        final items = ConversationQuestions.promptTexts(questions);
        if (ConversationQuestions.displayText(questions).isEmpty) {
          return '';
        }
        final title = value(questions, 'title').trim().isNotEmpty
            ? value(questions, 'title')
            : event.text.trim().isNotEmpty
            ? event.text.trim()
            : value(data, 'text').trim().isNotEmpty
            ? value(data, 'text').trim()
            : '再确认几件事';
        return switch (items.length) {
          0 => title,
          1 => items.first.trim().isEmpty ? title : items.first.trim(),
          _ => '$title：${items.join('，')}',
        };
      case 'SHOW_OPTIONS':
        final options = object('options');
        final items = ConversationMessages.array(
          options['items'] ?? options['optionsJson'],
        ).map(ConversationMessages.object).toList();
        List<String> tags(Map<String, Object?> item) =>
            ConversationMessages.array(
              item['tags'],
            ).whereType<String>().map((e) => e.toLowerCase()).toList();
        final place = items.any(
          (item) =>
              value(item, 'address').trim().isNotEmpty ||
              item['distanceMeters'] != null ||
              RegExp(
                'restaurant|store|merchant|餐厅|门店|商家',
              ).hasMatch(tags(item).join('|')),
        );
        const ordinals = ['一', '二', '三', '四', '五', '六', '七', '八', '九', '十'];
        final labels = <String>[];
        for (var i = 0; i < items.length; i++) {
          final item = items[i], phone = value(items[i], 'phone').trim();
          final label = value(item, 'label');
          labels.add(
            '第${i < 10 ? ordinals[i] : i + 1}${place ? '家' : '个'}，$label${tags(item).contains('contact') && phone.isNotEmpty ? '，$phone' : ''}',
          );
        }
        return '${options['title'] is String ? options['title'] : '请选择'}。${labels.join('。')}';
      case 'REQUEST_PERMISSION':
        final reason = value(object('permissionRequest'), 'reason');
        return reason.trim().isEmpty ? '需要你授权后才能继续' : reason;
      case 'IMPORT_DOCUMENT_REQUEST':
        final reason = value(object('documentImportRequest'), 'reason');
        return reason.trim().isEmpty ? '请上传 Markdown 或 TXT 文档' : reason;
      default:
        return ''; // Receipts require committed reply + terminal correlation.
    }
  }
}
