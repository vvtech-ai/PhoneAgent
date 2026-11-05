/// A private, scope-isolated namespace. Implementations serialize transactions
/// across instances and atomically replace a single file, never delete a tree.
abstract interface class DiagnosticArchiveFiles {
  Future<T> transaction<T>(Future<T> Function() action);
  Future<String?> read(String name);
  Future<void> replace(String name, String value);
  Future<List<String>> names();
  Future<void> remove(String name);
}
