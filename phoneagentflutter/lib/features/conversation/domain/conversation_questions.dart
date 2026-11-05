import 'dart:convert';

class ConversationQuestion {
  const ConversationQuestion({
    required this.id,
    required this.prompt,
    this.type = 'text',
    this.choices = const [],
    this.required = true,
    this.hint = '',
    this.defaultValue,
  });
  final String id, prompt, type, hint;
  final List<String> choices;
  final bool required;
  final Object? defaultValue;
}

/// Existing askUser payload and required-answer rules; no task state machine.
class ConversationQuestions {
  const ConversationQuestions(this.title, this.items);
  final String title;
  final List<ConversationQuestion> items;

  static String displayText(Map<String, Object?> data, {String fallback = ''}) {
    final title = data['title'] is String
        ? (data['title'] as String).trim()
        : '';
    final prompts = promptTexts(data);
    if (prompts.isEmpty &&
        (title.isEmpty ||
            title == '再确认几件事' ||
            data['_memoryRecallRequestSkipped'] == true)) {
      return '';
    }
    return [
      title.isNotEmpty
          ? title
          : fallback.isNotEmpty
          ? fallback
          : '再确认几件事',
      ...prompts.map((q) => '· $q'),
    ].join('\n');
  }

  static List<String> promptTexts(Map<String, Object?> payload) {
    var raw =
        payload['items'] ?? payload['questions'] ?? payload['questionsJson'];
    if (raw is String) {
      try {
        raw = jsonDecode(raw);
      } on FormatException {
        raw = null;
      }
    }
    if (raw is Map) raw = raw['items'];
    final prompts = raw is List
        ? raw
              .whereType<Map>()
              .map((value) => value['prompt'])
              .whereType<String>()
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList()
        : <String>[];
    if (prompts.isNotEmpty) return List.unmodifiable(prompts);
    final legacy = payload['question'];
    return legacy is String && legacy.trim().isNotEmpty
        ? [legacy.trim()]
        : const [];
  }

  static ConversationQuestions? parse(Map<String, Object?> payload) {
    var raw =
        payload['items'] ?? payload['questions'] ?? payload['questionsJson'];
    if (raw is String) {
      try {
        raw = jsonDecode(raw);
      } on FormatException {
        raw = null;
      }
    }
    if (raw is Map) raw = raw['items'];
    final ids = <String>{};
    final items = <ConversationQuestion>[];
    for (final value in raw is List ? raw : const <Object?>[]) {
      if (value is! Map) continue;
      final id = value['id'], prompt = value['prompt'];
      if (id is! String ||
          id.trim().isEmpty ||
          prompt is! String ||
          prompt.trim().isEmpty ||
          !ids.add(id)) {
        continue;
      }
      items.add(
        ConversationQuestion(
          id: id,
          prompt: prompt,
          type: value['answerType'] is String
              ? (value['answerType'] as String).toLowerCase()
              : 'text',
          choices:
              (value['choices'] is List ? value['choices'] as List : const [])
                  .whereType<String>()
                  .toList(),
          required: value['required'] != false,
          hint: value['hint'] is String ? value['hint'] as String : '',
          defaultValue: value['defaultValue'],
        ),
      );
    }
    if (items.isNotEmpty) {
      return ConversationQuestions(
        payload['title'] is String && (payload['title'] as String).isNotEmpty
            ? payload['title'] as String
            : '再确认几件事',
        List.unmodifiable(items),
      );
    }
    final legacy = payload['question'];
    if (legacy is String && legacy.trim().isNotEmpty) {
      return ConversationQuestions(
        payload['title'] is String && (payload['title'] as String).isNotEmpty
            ? payload['title'] as String
            : '再确认几件事',
        [ConversationQuestion(id: 'legacy_question', prompt: legacy.trim())],
      );
    }
    return null;
  }
}
