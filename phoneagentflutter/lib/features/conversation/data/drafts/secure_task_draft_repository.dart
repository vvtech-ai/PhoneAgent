import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/storage/app_local_storage.dart';
import '../../domain/drafts/task_draft.dart';
import 'task_draft_account_store.dart';

class SecureTaskDraftRepository implements TaskDraftRepository {
  SecureTaskDraftRepository(
    List<String> scope, {
    this.storage = const AppLocalStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
      ),
    ),
  }) : key = TaskDraftAccountStore.draftKey(scope),
       _account = TaskDraftAccountStore(
         scope.sublist(0, scope.length - 1),
         storage: storage,
       );
  final String key;
  final FlutterSecureStorage storage;
  final TaskDraftAccountStore _account;
  @override
  Future<TaskDraft?> read() async {
    final raw = await _account.read(key);
    if (raw == null) return null;
    final data = jsonDecode(raw);
    if (data is! Map ||
        data['text'] is! String ||
        data['start'] is! int ||
        data['end'] is! int) {
      throw const FormatException('Invalid task draft');
    }
    final text = data['text'] as String;
    return TaskDraft(
      text,
      start: (data['start'] as int).clamp(0, text.length),
      end: (data['end'] as int).clamp(0, text.length),
    );
  }

  @override
  Future<void> save(TaskDraft? draft) => draft == null || draft.text.isEmpty
      ? _account.save(key, null)
      : _account.save(
          key,
          jsonEncode({
            'text': draft.text,
            'start': draft.start.clamp(0, draft.text.length),
            'end': draft.end.clamp(0, draft.text.length),
          }),
        );
}
