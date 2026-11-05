import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as paths;
import 'pcm_recording_journal.dart';

/// File access is confined to one environment/account and a hashed call folder.
class PrivateDomesticRecordingFiles {
  PrivateDomesticRecordingFiles({
    required this.environment,
    required this.apiBase,
    required this.accountId,
    required this.root,
    required this.isCurrent,
  }) {
    if ([environment, apiBase, accountId].any((v) => v.trim().isEmpty)) {
      throw ArgumentError('Missing recording scope');
    }
  }
  final String environment, apiBase, accountId;
  final Future<Directory> Function() root;
  final bool Function() isCurrent;
  String get _scope => sha256
      .convert(utf8.encode(jsonEncode([environment, apiBase, accountId])))
      .toString();

  void _guard() {
    if (!isCurrent()) {
      throw StateError('Recording owner changed');
    }
  }

  Future<PcmRecordingJournal> create(
    String clientCallId,
    int originNanos,
  ) async {
    _guard();
    final directory = await root();
    _guard();
    final journal = await PcmRecordingJournal.create(
      privateRoot: directory,
      environment: environment,
      apiBase: apiBase,
      accountId: accountId,
      clientCallId: clientCallId,
      originNanos: originNanos,
    );
    if (!isCurrent()) {
      await journal.finish();
      _guard();
    }
    return journal;
  }

  Future<File> recording(String clientCallId) =>
      _ownedFile(clientCallId, 'recording.m4a');

  /// Only called after remote upload and durable pending removal succeeded.
  Future<void> removeArchived(String clientCallId) async {
    _guard();
    if (!RegExp(r'^[A-Za-z0-9_-]{1,160}$').hasMatch(clientCallId)) {
      throw const FormatException('Invalid recording call identifier');
    }
    final directory = await root();
    _guard();
    final call = sha256.convert(utf8.encode(clientCallId)).toString();
    var path = directory.path;
    for (final segment in ['', 'translation-recordings', _scope, call]) {
      if (segment.isNotEmpty) path = paths.join(path, segment);
      final type = await FileSystemEntity.type(path, followLinks: false);
      _guard();
      if (type == FileSystemEntityType.notFound) return;
      if (type != FileSystemEntityType.directory) {
        throw const FormatException('Invalid recording directory');
      }
    }
    const names = {
      'capture.pcmj',
      'capture.pcmj.complete',
      'mix.int32',
      'mix.pcm16',
      'recording.m4a',
      'recording.encoding.m4a',
      'recording.metadata.json',
      'recording.server-call.json',
      'recording.metadata.json.part',
    };
    final files = await Directory(path).list(followLinks: false).toList();
    _guard();
    for (final file in files) {
      if (!names.contains(file.uri.pathSegments.last) ||
          await FileSystemEntity.type(file.path, followLinks: false) !=
              FileSystemEntityType.file) {
        throw const FormatException('Unexpected recording directory content');
      }
      _guard();
    }
    for (final file in files) {
      _guard();
      await file.delete();
      _guard();
    }
    // Non-recursive deletion refuses content created after the preflight.
    await Directory(path).delete();
    _guard();
  }

  Future<PcmRecordingJournal> recover(String clientCallId) async {
    final file = await _ownedFile(clientCallId, 'capture.pcmj');
    final journal = await PcmRecordingJournal.recover(file);
    _guard();
    return journal;
  }

  Future<File> _ownedFile(String clientCallId, String name) async {
    _guard();
    if (!RegExp(r'^[A-Za-z0-9_-]{1,160}$').hasMatch(clientCallId)) {
      throw const FormatException('Invalid recording call identifier');
    }
    final directory = await root();
    final canonicalRoot = await directory.resolveSymbolicLinks();
    _guard();
    final call = sha256.convert(utf8.encode(clientCallId));
    final expected = paths.join(
      canonicalRoot,
      'translation-recordings',
      _scope,
      '$call',
      name,
    );
    final file = File(expected);
    final actual = await file.resolveSymbolicLinks();
    _guard();
    if (actual != expected) {
      throw const FormatException('Recording path escaped owner directory');
    }
    return file;
  }
}
