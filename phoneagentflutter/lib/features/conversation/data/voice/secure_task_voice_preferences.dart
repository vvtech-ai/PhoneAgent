import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/storage/app_local_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../domain/voice/task_voice_preferences.dart';

class SecureTaskVoicePreferences implements TaskVoicePreferenceRepository {
  const SecureTaskVoicePreferences({
    this.storage = const AppLocalStorage(
      preference: true,
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
      ),
    ),
  });
  final FlutterSecureStorage storage;
  static const _speech = 'task.voice.speech.enabled.v1',
      _guide = 'task.voice.guide.completed.v1';
  @override
  Future<TaskVoicePreferences> read() async {
    final values = await Future.wait([
      storage.read(key: _speech),
      storage.read(key: _guide),
    ]);
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        values.any((v) => v == null)) {
      final legacy = await const MethodChannel(
        'phone_agent/task_voice_preferences',
      ).invokeMapMethod<String, Object?>('readLegacy');
      for (final (index, field) in [
        'speechEnabled',
        'guideCompleted',
      ].indexed) {
        final old = legacy?[field];
        if (old != null && old is! bool) {
          throw const FormatException('Invalid legacy task preference');
        }
        if (values[index] == null && old is bool) {
          values[index] = '$old';
          await storage.write(
            key: index == 0 ? _speech : _guide,
            value: values[index],
          );
        }
      }
    }
    if (values.any((v) => v != null && v != 'true' && v != 'false')) {
      throw const FormatException('Invalid task voice preference');
    }
    return TaskVoicePreferences(
      speechEnabled: values[0] != 'false',
      guideCompleted: values[1] == 'true',
    );
  }

  @override
  Future<void> speech(bool enabled) =>
      storage.write(key: _speech, value: '$enabled');
  @override
  Future<void> completeGuide() => storage.write(key: _guide, value: 'true');
}
