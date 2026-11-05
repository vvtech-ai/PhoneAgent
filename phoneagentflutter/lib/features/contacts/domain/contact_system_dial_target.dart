/// Native contact handoff policy; unrelated to Agent or translation admission.
String contactSystemDialTarget(String raw) {
  final trimmed = raw.trim();
  final body = trimmed.replaceAll(RegExp(r'[^0-9*#]'), '');
  return body.isEmpty ? '' : '${trimmed.startsWith('+') ? '+' : ''}$body';
}
