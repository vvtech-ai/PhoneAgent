import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/diagnostics/diagnostic_archive.dart';
import '../../../../core/diagnostics/diagnostic_journal.dart';
import 'diagnostic_archive_cipher.dart';
import 'debug_readable_diagnostic_files.dart';
import 'directory_diagnostic_files.dart';
import 'encrypted_diagnostic_files.dart';
import 'secure_diagnostic_key.dart';
import 'secure_diagnostic_store.dart';

DiagnosticJournal createDiagnosticJournal(String scope) =>
    Platform.isAndroid || Platform.isIOS
    ? createFileDiagnosticJournal(scope)
    : DiagnosticJournal(SecureDiagnosticStore(scope));

/// Dependencies are injectable for real-directory, encrypted integration tests.
DiagnosticJournal createFileDiagnosticJournal(
  String scope, {
  Future<Directory> Function()? root,
  TargetPlatform? platform,
  bool allowDebugRead = true,
  FlutterSecureStorage storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  ),
}) {
  final legacy = SecureDiagnosticStore(scope, storage: storage);
  final key = SecureDiagnosticKey(scope, storage: storage);
  final readable =
      kDebugMode &&
      allowDebugRead &&
      (platform ?? defaultTargetPlatform) == TargetPlatform.android;
  return DiagnosticJournal.archived(() async {
    final directory = await (root ?? diagnosticPrivateRoot)();
    final files = EncryptedDiagnosticFiles(
      DirectoryDiagnosticFiles(directory, scope),
      scope,
      key.load,
    );
    return DiagnosticArchive(
      (platform ?? defaultTargetPlatform) == TargetPlatform.android
          ? DebugReadableDiagnosticFiles(
              files,
              DirectoryDiagnosticFiles(
                Directory('${directory.path}/readable-debug'),
                scope,
              ),
              readableWrites: readable,
            )
          : files,
      maxFileBytes: DiagnosticArchiveCipher.maxPlainBytes,
    );
  }, legacyStore: Platform.isIOS ? _NoLegacyDiagnosticStore() : legacy);
}

Future<Directory> diagnosticPrivateRoot() async {
  if (Platform.isIOS) {
    final info = await const MethodChannel(
      'phone_agent/diagnostic_directory',
    ).invokeMapMethod<String, dynamic>('directory');
    final path = info?['path'] as String?;
    if (path == null || path.isEmpty || !path.startsWith('/')) {
      throw StateError('Diagnostic private directory unavailable');
    }
    if (info?['excludedFromBackup'] != true ||
        info?['protectedUntilFirstUnlock'] != true) {
      throw StateError('Diagnostic private directory protection unavailable');
    }
    return Directory(path);
  }
  final support = await getApplicationSupportDirectory();
  return Directory('${support.path}/diagnostics-v2');
}

/// The first iOS release has no historical journal to import.
class _NoLegacyDiagnosticStore implements DiagnosticStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async {}
}
