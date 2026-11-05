/// A client display payload, not raw tool arguments or a durable call receipt.
class ConversationToolCard {
  const ConversationToolCard({
    required this.id,
    required this.toolName,
    required this.methodLabel,
    required this.body,
    required this.result,
    required this.status,
  });
  final String id, toolName, methodLabel, body, result, status;

  factory ConversationToolCard.fromPayload(Map<String, Object?> payload) {
    String text(String key) =>
        payload[key] is String ? (payload[key] as String).trim() : '';
    final method = text('methodLabel'), name = text('toolName');
    return ConversationToolCard(
      id: text('toolCallId'),
      toolName: name,
      methodLabel: method.isNotEmpty
          ? method
          : name.isNotEmpty
          ? name
          : 'tool()',
      body: text('body').isNotEmpty
          ? text('body')
          : _conditions(payload['conditions']),
      result: text('result'),
      status: text('status'),
    );
  }

  String get presentationKey => id.isNotEmpty
      ? 'id:$id'
      : 'semantic:$toolName\u0000$methodLabel\u0000$body';

  // v65 PureVoiceStepPresentationPolicy: ordinary traces disappear when the
  // turn stops streaming. Interactive cards defer to durable typed messages.
  bool get remainsAfterTurn => const {
    'showoptions',
    'askuser',
    'requestpermission',
    'importdocument',
  }.contains(toolName.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), ''));

  static String _conditions(Object? value) {
    if (value is! List) return '';
    final lines = <String>[];
    for (final item in value) {
      if (item is! Map) continue;
      final label = item['label'], entry = item['value'];
      if (label is! String || label.trim().isEmpty || entry == null) continue;
      if (entry is num || entry is bool) {
        lines.add('$label: $entry');
      } else if (entry is String && entry.trim().isNotEmpty) {
        lines.add('$label: "$entry"');
      }
    }
    return lines.join('\n');
  }
}
