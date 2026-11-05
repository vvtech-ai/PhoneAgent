import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/storage/app_local_storage.dart';
import '../../../core/storage/preference_operation_queue.dart';
import '../domain/task_voice.dart';

/// Device preference; intentionally independent of accounts and call voices.
class SecureTaskVoiceStore implements TaskVoiceStore {
  const SecureTaskVoiceStore({
    this.storage = const AppLocalStorage(
      preference: true,
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
      ),
    ),
  });
  final FlutterSecureStorage storage;
  static const key = 'phoneagent.task-voice.v1';
  @override
  Future<TaskVoice> read() => PreferenceOperationQueue.run(key, () async {
    final value = await storage.read(key: key);
    return value == null ? TaskVoice.maia : TaskVoice.parse(value);
  });
  @override
  Future<void> write(TaskVoice voice) => PreferenceOperationQueue.run(
    key,
    () => storage.write(key: key, value: voice.speaker),
  );
}
