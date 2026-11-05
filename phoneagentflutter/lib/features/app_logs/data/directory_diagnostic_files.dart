import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import '../../../../core/diagnostics/diagnostic_archive_files.dart';

/// App-private root is supplied by the platform factory, not a user path.
/// No plaintext credentials or free-form diagnostics belong in this namespace.
class DirectoryDiagnosticFiles implements DiagnosticArchiveFiles {
  DirectoryDiagnosticFiles(Directory root, String scope)
    : directory = Directory(
        '${root.absolute.path}/${sha256.convert(utf8.encode(scope))}',
      );

  final Directory directory;
  static final _tails = <String, Future<void>>{};
  static final _safeName = RegExp(
    r'^(index\.json|log-\d{4}-\d{2}-\d{2}-[1-9]\d*\.jsonl)$',
  );

  @override
  Future<T> transaction<T>(Future<T> Function() action) async {
    await directory.parent.create(recursive: true);
    await _directoryOnly(directory.parent);
    await _directoryOnly(directory);
    await directory.create();
    final key = await directory.resolveSymbolicLinks();
    final previous = _tails[key] ?? Future<void>.value();
    final result = previous.then((_) => action());
    final tail = result.then<void>((_) {}, onError: (Object _) {});
    _tails[key] = tail;
    try {
      return await result;
    } finally {
      if (identical(_tails[key], tail)) _tails.remove(key);
    }
  }

  Future<void> _directoryOnly(Directory value) async {
    final type = await FileSystemEntity.type(value.path, followLinks: false);
    if (type != FileSystemEntityType.notFound &&
        type != FileSystemEntityType.directory) {
      throw const FileSystemException('Diagnostic directory is not private');
    }
  }

  Future<File> _file(String name) async {
    if (!_safeName.hasMatch(name)) throw ArgumentError.value(name, 'name');
    final file = File('${directory.path}/$name');
    await _regularOrAbsent(file);
    return file;
  }

  Future<void> _regularOrAbsent(File file) async {
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type != FileSystemEntityType.notFound &&
        type != FileSystemEntityType.file) {
      throw const FileSystemException('Diagnostic file type rejected');
    }
  }

  @override
  Future<String?> read(String name) async {
    final file = await _file(name);
    return await file.exists() ? file.readAsString() : null;
  }

  @override
  Future<void> replace(String name, String value) async {
    final file = await _file(name);
    final pending = File('${file.path}.pending');
    await _regularOrAbsent(pending);
    await pending.writeAsString(value, flush: true);
    await pending.rename(file.path);
  }

  @override
  Future<List<String>> names() async => [
    await for (final entry in directory.list(followLinks: false))
      entry.uri.pathSegments.where((part) => part.isNotEmpty).last,
  ];

  @override
  Future<void> remove(String name) async {
    final File file;
    if (name.endsWith('.pending')) {
      final base = await _file(
        name.substring(0, name.length - '.pending'.length),
      );
      file = File('${base.path}.pending');
      await _regularOrAbsent(file);
    } else {
      file = await _file(name);
    }
    if (await file.exists()) await file.delete();
  }
}
