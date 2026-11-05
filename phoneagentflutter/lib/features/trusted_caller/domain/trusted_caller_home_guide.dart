import 'trusted_caller.dart';

/// Global display preferences, never an SDK authorization report.
abstract interface class TrustedCallerHomeGuideStore {
  Future<bool> eligible(TrustedCallerOwner owner);
  Future<void> record(TrustedCallerOwner owner, {required bool disabled});
}
