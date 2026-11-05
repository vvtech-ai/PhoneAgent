import '../../../core/network/account_api.dart';
import '../../../core/network/account_session.dart';
import '../domain/identity_profile.dart';

class ApiIdentityRepository implements IdentityRepository {
  ApiIdentityRepository(this._api, this.accountId);
  final AccountApi _api;
  final String accountId;
  static const _path = 'api/assistant/user-identity';
  @override
  Future<IdentityProfile> load() async =>
      _decode(await _api.request(_path, query: {'userId': accountId}));
  @override
  Future<IdentityProfile> delete() async => _decode(
    await _api.request(_path, method: 'DELETE', query: {'userId': accountId}),
  );
  @override
  Future<IdentityProfile> save(
    IdentityDraft draft, {
    required bool verified,
  }) async {
    if (draft.validation != null) throw draft.validation!;
    String? nonblank(String text) => text.trim().isEmpty ? null : text.trim();
    final work = draft.workIdentities
        .map((item) => item.normalized())
        .where((item) => item.company.isNotEmpty)
        .map(
          (item) => {
            'company': item.company,
            'department': item.department,
            'position': item.position,
          },
        )
        .toList();
    return _decode(
      await _api.request(
        _path,
        method: verified ? 'PATCH' : 'POST',
        body: {
          'userId': accountId,
          'gender': draft.gender.isEmpty ? '不透露' : draft.gender,
          'contactPhone': nonblank(draft.contactPhone),
          if (!verified) ...{
            'name': nonblank(draft.name),
            'workIdentities': work.isEmpty ? null : work,
            'description': nonblank(draft.description),
          },
        },
      ),
    );
  }

  IdentityProfile _decode(Object? value) {
    final dto = AccountApi.object(value);
    String text(Map<String, Object?> map, String key) {
      final v = map[key];
      if (v != null && v is! String) throw ApiFailure.invalidResponse;
      return v as String? ?? '';
    }

    final user = text(dto, 'userId');
    if (user.isNotEmpty && user != accountId) throw ApiFailure.sessionChanged;
    final work = dto['workIdentities'];
    if (work != null && work is! List) throw ApiFailure.invalidResponse;
    final items = (work as List? ?? [])
        .map(AccountApi.object)
        .map(
          (m) => WorkIdentity(
            company: text(m, 'company'),
            department: text(m, 'department'),
            position: text(m, 'position'),
          ),
        );
    return IdentityProfile(
      accountId: accountId,
      name: text(dto, 'name'),
      gender: text(dto, 'gender'),
      contactPhone: text(dto, 'contactPhone'),
      workIdentities: List.unmodifiable(items),
      description: text(dto, 'description'),
      verificationStatus: text(dto, 'verificationStatus'),
      certNoMasked: text(dto, 'certNoMasked'),
      verifiedAt: text(dto, 'verifiedAt'),
      updatedAt: text(dto, 'updatedAt'),
    );
  }
}
