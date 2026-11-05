class AccountCredentials {
  const AccountCredentials(this.accountId, this.token, this.epoch);
  final String accountId, token;
  final int epoch;

  bool sameLogin(AccountCredentials? other) =>
      other != null && accountId == other.accountId && epoch == other.epoch;
}

abstract interface class AccountSession {
  AccountCredentials? get credentials;
  Future<bool> replaceToken(AccountCredentials expected, String token);
  Future<void> rejectSession(AccountCredentials expected);
}

enum ApiFailure {
  unavailable,
  signedOut,
  sessionChanged,
  network,
  rejected,
  invalidResponse,
}

/// Selected status codes only; never contains a response body or credentials.
class ApiHttpFailure implements Exception {
  const ApiHttpFailure(this.statusCode);
  final int statusCode;
}

/// Only a caller-allowlisted wire code, never an arbitrary backend message.
class ApiCodeFailure implements Exception {
  const ApiCodeFailure(
    this.code, {
    this.statusCode = 0,
    this.retryable,
    this.recoveryAction,
  });
  final String code;
  final int statusCode;
  final bool? retryable;
  final String? recoveryAction;
}
