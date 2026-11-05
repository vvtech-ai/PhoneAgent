import 'auth_session.dart';

/// Authentication boundary. Implementations must not synthesize signed-in users.
abstract interface class AuthGateway {
  Future<CodeDelivery> sendCode(String phone);
  Future<LoginOutcome> login(LoginSubmission submission);
}

class CodeDelivery {
  const CodeDelivery(
    this.phone,
    this.cooldownSeconds, {
    this.expireSeconds = 0,
    this.eventId = '',
  });
  final String phone;
  final int cooldownSeconds;
  final int expireSeconds;
  final String eventId;
}

class LoginSubmission {
  const LoginSubmission({
    required this.phone,
    required this.code,
    this.activationCode,
    this.loginChallenge,
    this.registrationRequestId,
    this.invitationSource,
  });
  final String phone;
  final String code;
  final String? activationCode;
  final String? loginChallenge;
  final String? registrationRequestId, invitationSource;
}

class LoginOutcome {
  const LoginOutcome({
    required this.phone,
    required this.inviteRequired,
    this.loginChallenge = '',
    this.accessToken = '',
    this.accountId = '',
    this.displayName = '',
    this.points,
    this.grantEvents = const [],
    this.referralOperationId = '',
    this.referralPoints,
  });
  final String phone;
  final bool inviteRequired;
  final String loginChallenge;
  final String accessToken;
  final String accountId, displayName;
  final AuthPoints? points;
  final List<AuthGrantEvent> grantEvents;
  final String referralOperationId;
  final int? referralPoints;

  AuthSession toSession() => AuthSession(
    accountId: accountId,
    phone: phone,
    accessToken: accessToken,
    displayName: displayName,
  );
}

enum AuthFailure implements Exception {
  unavailable,
  rejected,
  network,
  timeout,
  offline,
  invalidResponse,
  storage,
  codeExpired,
  incorrectCode,
  challengeExpired,
  invalidInvite,
  rateLimited,
}

/// Mirrors v65 FinalContactMethodPolicy, including full-width pasted digits.
String sanitizeLoginPhone(String value, [String previous = '']) {
  String digits(String input) {
    var result = input.runes.map((rune) {
      if (rune >= 0xff10 && rune <= 0xff19) rune -= 0xfee0;
      return rune >= 48 && rune <= 57 ? String.fromCharCode(rune) : '';
    }).join();
    if (result.startsWith('0086') && result.length > 4) {
      result = result.substring(4);
    } else if (result.startsWith('86') && result.length > 2) {
      result = result.substring(2);
    }
    return result.length > 11 ? result.substring(0, 11) : result;
  }

  bool allowed(String phone) =>
      phone.isEmpty || phone == '1' || RegExp(r'^1[3-9]\d*$').hasMatch(phone);
  final candidate = digits(value);
  if (allowed(candidate)) return candidate;
  final fallback = digits(previous);
  return allowed(fallback) ? fallback : '';
}

bool isLoginPhone(String value) => RegExp(r'^1[3-9]\d{9}$').hasMatch(value);
bool isSmsCode(String value) => RegExp(r'^[0-9]{4,8}$').hasMatch(value.trim());

/// Display message only; diagnostics must never serialize this exception.
class AuthMessageFailure implements Exception {
  const AuthMessageFailure(this.message);
  final String message;
}

String authExceptionMessage(Object error) {
  final message = switch (error) {
    AuthMessageFailure e => e.message,
    AuthFailure _ => '',
    StateError e => e.message,
    ArgumentError e => e.message is String ? e.message as String : '',
    Exception e => e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''),
    _ => '',
  };
  return message.trim().isEmpty ? '登录失败' : message.trim();
}
