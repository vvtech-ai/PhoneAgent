import '../domain/trusted_caller.dart';

/// Deliberately performs no device or SDK work until deployment is configured.
class UnconfiguredTrustedCallerPort implements TrustedCallerPort {
  const UnconfiguredTrustedCallerPort();

  @override
  Future<bool> prepare(TrustedCallerOwner owner) async => false;

  @override
  Future<TrustedCallerReport> readStatus(TrustedCallerOwner owner) =>
      Future.error(const TrustedCallerFailure('SDK_NOT_CONFIGURED'));

  @override
  Future<void> openSettings(TrustedCallerOwner owner) =>
      Future.error(const TrustedCallerFailure('SDK_NOT_CONFIGURED'));

  @override
  Future<void> releaseSurface(TrustedCallerOwner owner) async {}
}
