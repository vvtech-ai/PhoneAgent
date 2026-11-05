import '../../../core/network/account_api.dart';
import '../../../core/network/account_session.dart';
import '../domain/contact_records.dart';

class ApiContactDirectoryRepository
    implements ContactDirectoryRepository, ContactDirectoryDeletionPort {
  ApiContactDirectoryRepository(this._api, this.accountId);
  final AccountApi _api;
  final String accountId;
  static const _path = 'api/assistant/contacts';

  @override
  Future<void> deleteRemark(String phoneKey) async {
    if (!RegExp(r'^[0-9]+$').hasMatch(phoneKey)) {
      throw ApiFailure.invalidResponse;
    }
    await _api.request(
      '$_path/$phoneKey',
      method: 'DELETE',
      query: {'userId': accountId},
    );
  }

  @override
  Future<List<ContactDirectoryEntry>> load() async {
    final data = await _api.request(_path, query: {'userId': accountId});
    if (data is! List) throw ApiFailure.invalidResponse;
    return List.unmodifiable(data.map(_decode));
  }

  @override
  Future<ContactDirectoryEntry> saveRemark({
    required ContactRecord contact,
    required String remark,
    ContactDirectoryEntry? existing,
  }) async {
    if (contact.key.isEmpty ||
        existing != null && existing.key != contact.key) {
      throw ApiFailure.invalidResponse;
    }
    final fallback = contact.name.trim();
    final result = _decode(
      await _api.request(
        _path,
        method: 'POST',
        body: {
          'userId': accountId,
          'phone': contact.key,
          // Preserve even an existing empty string; v65 falls back only on null.
          'displayName':
              existing?.displayName ?? (fallback.isEmpty ? null : fallback),
          'primaryRelation': existing?.primaryRelation,
          'speakingStyle': existing?.speakingStyle,
          'description': remark.trim().isEmpty ? null : remark.trim(),
        },
      ),
    );
    if (result.key != contact.key) throw ApiFailure.invalidResponse;
    return result;
  }

  ContactDirectoryEntry _decode(Object? value) {
    final dto = AccountApi.object(value);
    String? text(String key) {
      final raw = dto[key];
      if (raw != null && raw is! String) throw ApiFailure.invalidResponse;
      return raw as String?;
    }

    final entry = ContactDirectoryEntry(
      phone: text('phone') ?? '',
      displayName: text('displayName'),
      primaryRelation: text('primaryRelation'),
      speakingStyle: text('speakingStyle'),
      description: text('description'),
      updatedAt: text('updatedAt'),
    );
    if (entry.key.isEmpty) throw ApiFailure.invalidResponse;
    return entry;
  }
}
