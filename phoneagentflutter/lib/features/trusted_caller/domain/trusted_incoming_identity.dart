import 'trusted_caller.dart';

enum TrustedIdentityVerification { pending, failed, verified, uncertified }

class TrustedIncomingIdentity {
  const TrustedIncomingIdentity({
    required this.owner,
    required this.eventId,
    required this.verification,
    this.displayType = 0,
    this.name = '',
    this.title = '',
    this.department = '',
    this.position = '',
    this.company = '',
    this.caller = '',
    this.target = '',
    this.sequence = '',
    this.job = '',
    this.school = '',
    this.serial = '',
    this.issuedAt = '',
    this.issuer = '',
    this.callTime = '',
    this.activityFresh = false,
    this.presentationRevision = 0,
    this.avatarData = const [],
  });
  final List<int> avatarData;
  final TrustedCallerOwner owner;
  final String eventId;
  final TrustedIdentityVerification verification;
  final int displayType;
  final String name, title, department, position, company;
  final String caller, target, sequence, job, school, serial;
  final String issuedAt, issuer, callTime;
  final bool activityFresh;
  final int presentationRevision;
  String get presentationId =>
      presentationRevision == 0 ? eventId : '$eventId:$presentationRevision';

  bool get hasCertificate =>
      verification == TrustedIdentityVerification.verified && displayType != 6;
}

abstract interface class TrustedIncomingIdentityPort {
  Stream<TrustedIncomingIdentity?> watch(
    TrustedCallerOwner owner,
    String environment,
  );
}
