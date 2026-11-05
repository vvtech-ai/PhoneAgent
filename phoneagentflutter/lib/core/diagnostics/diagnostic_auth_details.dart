/// Only fixed categories cross the authentication diagnostics boundary.
enum DiagnosticAuthOutcome {
  codeAccepted,
  inviteRequired,
  credentialsReturned,
  unavailable,
  rejected,
  network,
  invalidResponse,
  storage,
  codeExpired,
  incorrectCode,
  challengeExpired,
  invalidInvite,
  rateLimited,
  unknown,
}

class DiagnosticAuthDetails {
  const DiagnosticAuthDetails(this.outcome);
  final DiagnosticAuthOutcome outcome;

  Map<String, Object> toJson() => {'outcome': outcome.name};

  factory DiagnosticAuthDetails.fromJson(Map<String, dynamic> json) =>
      DiagnosticAuthDetails(
        DiagnosticAuthOutcome.values.firstWhere(
          (value) => value.name == json['outcome'],
          orElse: () => DiagnosticAuthOutcome.unknown,
        ),
      );
}
