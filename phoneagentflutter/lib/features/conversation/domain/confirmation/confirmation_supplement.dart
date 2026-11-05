class ConfirmationSupplement {
  const ConfirmationSupplement({
    required this.id,
    required this.toolId,
    required this.userText,
    required this.assistantText,
  });
  final String id, toolId, userText, assistantText;
}

abstract interface class ConfirmationSupplementStore {
  Future<List<ConfirmationSupplement>> read();
  Future<void> write(List<ConfirmationSupplement> records);
}

abstract interface class ConfirmationSupplementRepository {
  Future<String> save(String sessionId, ConfirmationSupplement record);
}
