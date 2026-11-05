import '../domain/auth_gateway.dart';

/// Explicit boundary until the real authentication adapter is implemented.
/// This is not a mock: it never returns an authenticated identity.
class UnavailableAuthGateway implements AuthGateway {
  const UnavailableAuthGateway();

  @override
  Future<CodeDelivery> sendCode(String phone) async =>
      throw AuthFailure.unavailable;

  @override
  Future<LoginOutcome> login(LoginSubmission submission) async =>
      throw AuthFailure.unavailable;
}
