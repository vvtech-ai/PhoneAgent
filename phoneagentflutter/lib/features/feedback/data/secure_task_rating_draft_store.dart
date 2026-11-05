import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/storage/app_local_storage.dart';
import '../../../core/config/app_config.dart';
import '../domain/task_rating.dart';
import '../domain/task_rating_draft_store.dart';

/// Serial storage per account scope prevents an earlier keystroke overwriting a
/// persisted submission key, or a late save resurrecting a cleared draft.
class SecureTaskRatingDraftStore implements TaskRatingDraftStore {
  SecureTaskRatingDraftStore(
    AppConfig config,
    String accountId, {
    FlutterSecureStorage? storage,
    Future<SavedRatingDraft?> Function(TaskRatingEligibility)? legacyRead,
  }) : _scope = scopeFor(config, accountId),
       _legacyRead = legacyRead,
       _storage =
           storage ??
           const AppLocalStorage(
             aOptions: AndroidOptions(encryptedSharedPreferences: true),
             iOptions: IOSOptions(
               accessibility: KeychainAccessibility.unlocked_this_device,
             ),
           );
  final String _scope;
  final FlutterSecureStorage _storage;
  final Future<SavedRatingDraft?> Function(TaskRatingEligibility)? _legacyRead;
  static final _tails = <String, Future<void>>{};
  bool _closed = false;
  void close() => _closed = true;
  void _checkOpen() {
    if (_closed) throw StateError('Rating draft store closed');
  }

  static String scopeFor(AppConfig config, String accountId) {
    if (!config.isConfigured || accountId.trim().isEmpty) {
      throw StateError('Missing draft scope');
    }
    final uri = config.apiBaseUri!;
    final path = uri.path.endsWith('/') ? uri.path : '${uri.path}/';
    return jsonEncode([
      config.environment!.name,
      uri.replace(path: path).toString(),
      accountId,
    ]);
  }

  String _key(TaskRatingEligibility e) {
    if (e.taskType.isEmpty || e.taskId.isEmpty) {
      throw StateError('Missing task scope');
    }
    return 'phoneagent.rating.v1.${base64Url.encode(utf8.encode(jsonEncode([_scope, e.taskType, e.taskId])))}';
  }

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = (_tails[_scope] ?? Future<void>.value()).then((_) {
      _checkOpen();
      return action();
    });
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    _tails[_scope] = tail;
    tail.then((_) {
      if (identical(_tails[_scope], tail)) _tails.remove(_scope);
    });
    return result;
  }

  @override
  Future<SavedRatingDraft?> read(TaskRatingEligibility e) => _serial(() async {
    final raw = await _storage.read(key: _key(e));
    _checkOpen();
    if (raw == null) {
      if (_legacyRead == null) return null;
      final legacy = await _legacyRead(e);
      _checkOpen();
      await _write(e, legacy);
      _checkOpen();
      return legacy;
    }
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      if (m['schema'] != 1) {
        throw const FormatException('Unsupported rating draft');
      }
      if (m['cleared'] == true) return null;
      for (final field in ['understanding', 'call', 'completion', 'clone']) {
        final value = m[field];
        if (value != null && (value is! int || value < 1 || value > 5)) {
          throw const FormatException('Invalid rating draft');
        }
      }
      return SavedRatingDraft(
        TaskRatingDraft(
          taskUnderstanding: m['understanding'] as int?,
          aiCallPerformance: m['call'] as int?,
          taskCompletion: m['completion'] as int?,
          cloneVoicePerformance: m['clone'] as int?,
          cloneVoiceNotEvaluated: m['skipClone'] as bool,
          suggestion: m['suggestion'] as String,
        ),
        submissionKey: m['key'] as String,
      );
    } catch (_) {
      // Do not expose private JSON or treat unreadable content as absent.
      throw const FormatException('Rating draft unavailable');
    }
  });
  @override
  Future<void> save(TaskRatingEligibility e, SavedRatingDraft saved) =>
      _serial(() => _write(e, saved));

  Future<void> _write(TaskRatingEligibility e, SavedRatingDraft? saved) {
    _checkOpen();
    final d = saved?.draft;
    return _storage.write(
      key: _key(e),
      value: jsonEncode(
        d == null
            ? {'schema': 1, 'cleared': true}
            : {
                'schema': 1,
                'understanding': d.taskUnderstanding,
                'call': d.aiCallPerformance,
                'completion': d.taskCompletion,
                'clone': d.cloneVoicePerformance,
                'skipClone': d.cloneVoiceNotEvaluated,
                'suggestion': d.suggestion,
                'key': saved!.submissionKey,
              },
      ),
    );
  }

  @override
  Future<void> clear(TaskRatingEligibility e) => _serial(() => _write(e, null));
}
