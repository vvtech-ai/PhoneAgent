import 'conversation_messages.dart';

/// Candidate equivalence within a real user turn, not a global text deduper.
abstract final class ConversationOptionPresentation {
  static int ownerIndex(
    List<ConversationMessage> visible,
    int turnStart,
    ConversationMessage incoming,
  ) {
    if (!_eligible(incoming)) return -1;
    final labels = _labels(incoming);
    if (labels.isEmpty) return -1;
    for (var index = visible.length - 1; index >= turnStart; index--) {
      final prior = visible[index];
      if (!_eligible(prior)) continue;
      final leftId = prior.toolCallId?.trim() ?? '';
      final rightId = incoming.toolCallId?.trim() ?? '';
      if (leftId.isNotEmpty && rightId.isNotEmpty && leftId != rightId) {
        continue;
      }
      final priorContacts = _contacts(prior);
      final incomingContacts = _contacts(incoming);
      final sameCandidates = priorContacts != null && incomingContacts != null
          ? _equal(priorContacts, incomingContacts)
          : _equal(_labels(prior), labels);
      if (sameCandidates &&
          (_generic(prior) ||
              _generic(incoming) ||
              prior.options.isNotEmpty &&
                  incoming.options.isNotEmpty &&
                  _title(prior) == _title(incoming))) {
        return index;
      }
    }
    return -1;
  }

  static ConversationMessage merge(
    ConversationMessage prior,
    ConversationMessage incoming,
  ) {
    if (incoming.options.isNotEmpty) {
      if ((prior.toolCallId?.isNotEmpty ?? false) &&
          (incoming.toolCallId?.isEmpty ?? true)) {
        return prior.copyWith(text: incoming.text, options: incoming.options);
      }
      return incoming;
    }
    if (prior.options.isNotEmpty) return prior;
    return _generic(prior) && !_generic(incoming) ? incoming : prior;
  }

  static bool _eligible(ConversationMessage message) =>
      message.role == MessageRole.assistant &&
      message.thinking == null &&
      message.toolCard == null &&
      message.confirmation == null &&
      message.batchConfirmation == null &&
      message.receipt == null &&
      message.batchReceipt == null &&
      message.artifact == null &&
      message.document == null &&
      message.questionSourceText == null &&
      message.questions == null;
  static String _title(ConversationMessage message) =>
      message.text.split('\n').first.trim();
  static bool _generic(ConversationMessage message) =>
      _title(message) == '搜到的结果';
  static List<String> _labels(ConversationMessage message) =>
      message.options.isNotEmpty
      ? message.options.map((option) => option.label.trim()).toList()
      : message.text
            .split('\n')
            .map((line) => _numbered.firstMatch(line)?.group(1)?.trim())
            .whereType<String>()
            .where((label) => label.isNotEmpty)
            .toList();

  static List<String>? _contacts(ConversationMessage message) {
    if (message.options.isEmpty || !message.options.every((o) => o.isContact)) {
      return null;
    }
    final names = <String>[], tails = <String>[];
    for (final option in message.options) {
      final match = _phoneSuffix.firstMatch(option.label.trim());
      names.add(match?.group(1)?.trim() ?? option.label.trim());
      final digits = (match?.group(2) ?? option.phone).replaceAll(
        RegExp(r'\D'),
        '',
      );
      tails.add(digits.length >= 4 ? digits.substring(digits.length - 4) : '');
    }
    final counts = <String, int>{};
    for (final name in names) {
      counts[name] = (counts[name] ?? 0) + 1;
    }
    return [
      for (var i = 0; i < names.length; i++)
        counts[names[i]]! > 1
            ? '${names[i]}\u0000${tails[i].isEmpty ? message.id : tails[i]}'
            : names[i],
    ];
  }

  static bool _equal(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }

  static final _numbered = RegExp(
    r'^\s*\d+\s*[.、．]\s*([^（(|]+?)(?:\s*[（(|].*)?\s*$',
  );
  static final _phoneSuffix = RegExp(
    r'^(.*?)[（(]\s*(?:尾号\s*)?([+]?\d[\d\s-]{3,})\s*[）)]\s*$',
  );
}
