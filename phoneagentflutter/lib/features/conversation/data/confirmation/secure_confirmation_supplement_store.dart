import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/storage/app_local_storage.dart';
import '../../domain/confirmation/confirmation_supplement.dart';

class SecureConfirmationSupplementStore implements ConfirmationSupplementStore {
  SecureConfirmationSupplementStore(
    List<String> scope, {
    this.storage = const AppLocalStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
      ),
    ),
  }) : key =
           'task.confirmation.outbox.${sha256.convert(utf8.encode(jsonEncode(scope)))}';
  final String key;
  final FlutterSecureStorage storage;
  @override
  Future<List<ConfirmationSupplement>> read() async {
    final raw = await storage.read(key: key);
    if (raw == null) return [];
    final data = jsonDecode(raw);
    if (data is! List) {
      throw const FormatException('Invalid confirmation outbox');
    }
    return data.map((value) {
      if (value is! Map ||
          !['id', 'toolId', 'userText', 'assistantText'].every(
            (field) =>
                value[field] is String && (value[field] as String).isNotEmpty,
          )) {
        throw const FormatException('Invalid confirmation outbox');
      }
      return ConfirmationSupplement(
        id: value['id'] as String,
        toolId: value['toolId'] as String,
        userText: value['userText'] as String,
        assistantText: value['assistantText'] as String,
      );
    }).toList();
  }

  @override
  Future<void> write(List<ConfirmationSupplement> records) => storage.write(
    key: key,
    value: jsonEncode(
      records
          .map(
            (r) => {
              'id': r.id,
              'toolId': r.toolId,
              'userText': r.userText,
              'assistantText': r.assistantText,
            },
          )
          .toList(),
    ),
  );
}
