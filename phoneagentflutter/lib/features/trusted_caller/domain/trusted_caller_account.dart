import 'trusted_caller.dart';

/// Account incoming registration has a different lifetime from settings UI.
abstract interface class TrustedCallerAccountPort {
  Future<bool> updateAccount(TrustedCallerOwner? owner, String environment);
}
