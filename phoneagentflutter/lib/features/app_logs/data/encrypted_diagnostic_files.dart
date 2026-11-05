import 'dart:convert';
import 'dart:isolate';
import 'package:crypto/crypto.dart';
import '../../../../core/diagnostics/diagnostic_archive_files.dart';
import 'diagnostic_archive_cipher.dart';

/// IO-only adapter: expensive crypto runs off the UI isolate. The underlying
/// scope transaction also serializes key creation across separate instances.
class EncryptedDiagnosticFiles implements DiagnosticArchiveFiles {
  EncryptedDiagnosticFiles(this.delegate, String scope, this.loadKey)
    : binding = sha256.convert(utf8.encode(scope)).toString();
  final DiagnosticArchiveFiles delegate;
  final Future<List<int>> Function({required bool allowCreate}) loadKey;
  final String binding;
  List<int>? _key;

  @override
  Future<T> transaction<T>(Future<T> Function() action) =>
      delegate.transaction(() async {
        final names = await delegate.names();
        _key = List<int>.of(
          await loadKey(
            allowCreate: !names.any(
              (name) =>
                  name.startsWith('index.json') || name.startsWith('log-'),
            ),
          ),
        );
        try {
          return await action();
        } finally {
          _key?.fillRange(0, _key!.length, 0);
          _key = null;
        }
      });

  List<int> _copyKey() {
    final key = _key;
    if (key == null || key.length != 32) {
      throw StateError('Diagnostic transaction required');
    }
    return List<int>.of(key);
  }

  @override
  Future<String?> read(String name) async {
    final text = await delegate.read(name);
    if (text == null) return null;
    final key = _copyKey();
    final aad = '$binding|$name';
    return Isolate.run(() => DiagnosticArchiveCipher.decrypt(text, key, aad));
  }

  @override
  Future<void> replace(String name, String value) async {
    final key = _copyKey();
    final aad = '$binding|$name';
    final encrypted = await Isolate.run(
      () => DiagnosticArchiveCipher.encrypt(value, key, aad),
    );
    await delegate.replace(name, encrypted);
  }

  @override
  Future<List<String>> names() => delegate.names();
  @override
  Future<void> remove(String name) => delegate.remove(name);
}
