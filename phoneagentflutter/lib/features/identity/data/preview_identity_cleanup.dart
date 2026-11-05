import '../domain/identity_profile.dart';
import '../domain/identity_deletion_cleanup.dart';

/// Disposable, memory-only failure scenario; never reaches an account API.
class PreviewIdentityCleanup implements IdentityRepository {
  IdentityProfile value = const IdentityProfile(
    accountId: 'synthetic',
    name: '合成身份',
  );
  int deletes = 0, skipWrites = 0, clearAttempts = 0;
  @override
  Future<IdentityProfile> load() async => value;
  @override
  Future<IdentityProfile> save(
    IdentityDraft draft, {
    required bool verified,
  }) async => value = IdentityProfile(
    accountId: 'synthetic',
    name: verified ? value.name : draft.name,
    gender: draft.gender,
    contactPhone: draft.contactPhone,
    verificationStatus: verified ? value.verificationStatus : '',
  );
  @override
  Future<IdentityProfile> delete() async {
    deletes++;
    return value = const IdentityProfile(accountId: 'synthetic');
  }

  IdentityDeletionCleanup createCleanup() {
    var failed = false;
    return IdentityDeletionCleanup(
      markSkipped: () async {
        skipWrites++;
      },
      clearRecording: () async {
        clearAttempts++;
        if (!failed) {
          failed = true;
          throw StateError('Synthetic first clear failure');
        }
      },
    );
  }
}
