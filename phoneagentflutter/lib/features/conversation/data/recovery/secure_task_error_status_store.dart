import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/storage/app_local_storage.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/storage/preference_operation_queue.dart';
import '../../domain/recovery/task_error_status_command.dart';

/// The old Android set has no account provenance and is intentionally untouched.
class SecureTaskErrorStatusStore implements TaskErrorStatusStore {
  SecureTaskErrorStatusStore(
    AppConfig config,
    String accountId, {
    FlutterSecureStorage? storage,
    bool Function()? isCurrent,
  }) : key = keyFor(config, accountId),
       _isCurrent = isCurrent ?? (() => true),
       _storage =
           storage ??
           const AppLocalStorage(
             aOptions: AndroidOptions(encryptedSharedPreferences: true),
             iOptions: IOSOptions(
               accessibility: KeychainAccessibility.unlocked_this_device,
             ),
           );

  final String key;
  final FlutterSecureStorage _storage;
  final bool Function() _isCurrent;

  static String keyFor(AppConfig config, String accountId) {
    if (!config.isConfigured || accountId.trim().isEmpty) {
      throw StateError('Missing task status scope');
    }
    final base = config.apiBaseUri!;
    final path = base.path.endsWith('/') ? base.path : '${base.path}/';
    final scope = jsonEncode([
      config.environment!.name,
      base.replace(path: path).toString(),
      accountId,
    ]);
    return 'phoneagent.task-error.v1.${sha256.convert(utf8.encode(scope))}';
  }

  void _check() {
    if (!_isCurrent()) throw StateError('Task status account changed');
  }

  Future<Map<String, TaskErrorStatusCommand>> _read() async {
    _check();
    final raw = await _storage.read(key: key);
    _check();
    if (raw == null) return {};
    try {
      if (utf8.encode(raw).length > 1024 * 1024) throw const FormatException();
      final root = jsonDecode(raw);
      if (root is! Map<String, dynamic> ||
          root['schema'] != 1 ||
          root['commands'] is! List) {
        throw const FormatException();
      }
      final commands = <String, TaskErrorStatusCommand>{};
      for (final item in root['commands'] as List) {
        final command = TaskErrorStatusCommand.fromJson(item);
        if (commands.containsKey(command.sessionId)) {
          throw const FormatException();
        }
        commands[command.sessionId] = command;
      }
      return commands;
    } catch (_) {
      // Never expose raw storage or overwrite a damaged queue with empty data.
      throw const FormatException('Invalid task status store');
    }
  }

  Future<void> _write(Map<String, TaskErrorStatusCommand> commands) async {
    _check();
    final raw = jsonEncode({
      'schema': 1,
      'commands': commands.values.map((c) => c.toJson()).toList(),
    });
    if (utf8.encode(raw).length > 1024 * 1024) {
      throw StateError('Task status store capacity exceeded');
    }
    await _storage.write(key: key, value: raw);
    _check();
  }

  @override
  Future<List<TaskErrorStatusCommand>> read() => PreferenceOperationQueue.run(
    key,
    () async => List.unmodifiable((await _read()).values),
  );

  @override
  Future<void> put(TaskErrorStatusCommand command) =>
      PreferenceOperationQueue.run(key, () async {
        final commands = await _read();
        commands[command.sessionId] = command;
        await _write(commands);
      });

  @override
  Future<void> removeIfCurrent(TaskErrorStatusCommand command) =>
      PreferenceOperationQueue.run(key, () async {
        final commands = await _read();
        if (commands[command.sessionId]?.commandId != command.commandId) return;
        commands.remove(command.sessionId);
        await _write(commands);
      });
}
