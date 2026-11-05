enum DiagnosticCloneField {
  attemptId,
  certifyId,
  scriptText,
  expiresAt,
  scriptVersion,
  scriptTemplateId,
  replacementRequired,
  providerSubCode,
  candidate,
  candidateId,
  modelId,
  status,
  source,
  billingStatus,
  displayName,
  lastError,
  providerAssetId,
  chargedPoints,
  remainingPoints,
  updatedAt,
}

enum DiagnosticJsonType { absent, text, number, boolean, object, array, other }

/// Only schema metadata; never stores a response value or identifier.
class DiagnosticCloneDetails {
  const DiagnosticCloneDetails(this.field, this.type);
  final DiagnosticCloneField field;
  final DiagnosticJsonType type;
  Map<String, Object> toJson() => {'field': field.name, 'type': type.name};
  factory DiagnosticCloneDetails.fromJson(Map<String, dynamic> json) =>
      DiagnosticCloneDetails(
        DiagnosticCloneField.values.byName(json['field'] as String),
        DiagnosticJsonType.values.byName(json['type'] as String),
      );
}
