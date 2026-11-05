import '../../../../core/diagnostics/diagnostic_archive_files.dart';

/// Android Debug only. The encrypted archive remains authoritative; a scoped
/// readable mirror lets an authorized ADB shell inspect sanitized diagnostics.
class DebugReadableDiagnosticFiles implements DiagnosticArchiveFiles {
  DebugReadableDiagnosticFiles(
    this.delegate,
    this.mirror, {
    this.readableWrites = true,
  });

  final DiagnosticArchiveFiles delegate;
  final DiagnosticArchiveFiles mirror;
  final bool readableWrites;

  @override
  Future<T> transaction<T>(Future<T> Function() action) =>
      delegate.transaction(() async {
        try {
          return await action();
        } finally {
          await _collectMirror().catchError((Object _) {});
        }
      });

  Future<void> _collectMirror() async {
    List<String> names;
    try {
      names = await mirror.names();
    } catch (_) {
      return; // Do not create a readable directory in protected builds.
    }
    final retained = readableWrites
        ? (await delegate.names()).toSet()
        : <String>{};
    final safeName = RegExp(
      r'^(index\.json|log-\d{4}-\d{2}-\d{2}-[1-9]\d*\.jsonl)(\.pending)?$',
    );
    await _mirror(() async {
      for (final name in names) {
        if (safeName.hasMatch(name) &&
            (name.endsWith('.pending') || !retained.contains(name))) {
          await mirror.remove(name);
        }
      }
    });
  }

  @override
  Future<String?> read(String name) async {
    final text = await delegate.read(name);
    if (readableWrites && text != null) {
      await _mirror(() => mirror.replace(name, text));
    }
    return text;
  }

  Future<void> _mirror(Future<void> Function() action) async {
    try {
      await mirror.transaction(action);
    } catch (_) {
      /* A diagnostic mirror cannot break the authoritative journal. */
    }
  }

  @override
  Future<void> replace(String name, String value) async {
    await delegate.replace(name, value);
    if (readableWrites) await _mirror(() => mirror.replace(name, value));
  }

  @override
  Future<List<String>> names() => delegate.names();

  @override
  Future<void> remove(String name) async {
    await delegate.remove(name);
    await _mirror(() => mirror.remove(name));
  }
}
