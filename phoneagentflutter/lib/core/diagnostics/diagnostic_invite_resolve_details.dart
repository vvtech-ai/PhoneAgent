/// Fixed public-query categories; raw response text and invite URLs never cross.
enum DiagnosticInviteResolveOutcome {
  started,
  active,
  activityRetired,
  expired,
  exhausted,
  replaced,
  invalidCode,
  activityChanged,
  configNotPublished,
  configSyncPending,
  serviceUnavailable,
  network,
  invalidResponse,
  configUnavailable,
  unknown,
}

enum DiagnosticInviteApiCode {
  unknown,
  numericSuccess,
  stringSuccess,
  rejected,
}

class DiagnosticInviteResolveDetails {
  const DiagnosticInviteResolveDetails(this.outcome, this.apiCode);
  final DiagnosticInviteResolveOutcome outcome;
  final DiagnosticInviteApiCode apiCode;
  Map<String, Object> toJson() => {
    'outcome': outcome.name,
    'apiCode': apiCode.name,
  };
  factory DiagnosticInviteResolveDetails.fromJson(Map<String, dynamic> json) =>
      DiagnosticInviteResolveDetails(
        DiagnosticInviteResolveOutcome.values.firstWhere(
          (v) => v.name == json['outcome'],
          orElse: () => DiagnosticInviteResolveOutcome.unknown,
        ),
        DiagnosticInviteApiCode.values.firstWhere(
          (v) => v.name == json['apiCode'],
          orElse: () => DiagnosticInviteApiCode.unknown,
        ),
      );
}
