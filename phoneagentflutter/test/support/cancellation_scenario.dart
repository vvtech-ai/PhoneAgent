import 'package:phone_agent/features/account_cancellation/domain/account_cancellation.dart';

class CancellationScenario implements CancellationGateway {
  int confirmations = 0,
      sends = 0,
      verifications = 0,
      submissions = 0,
      queries = 0;
  bool failVerification = false;
  bool loseResponse = false, failQuery = false, notSubmitted = false;
  final confirmationData = CancellationConfirmation(
    'confirmation',
    '2026-10-26',
    'https://example.test/agreement',
    DateTime.utc(2026, 11, 10),
  );
  CancellationResult get result =>
      CancellationResult('application', 'PENDING', DateTime.utc(2026, 11, 10));
  @override
  Future<CancellationConfirmation> confirmation() async {
    confirmations++;
    return confirmationData;
  }

  @override
  Future<CancellationDelivery> send(
    CancellationConfirmation confirmation,
    String operationId,
  ) async {
    sends++;
    return const CancellationDelivery(
      'challenge',
      'query-secret',
      '138****0000',
      60,
    );
  }

  @override
  Future<CancellationVerification> verify(
    CancellationDelivery delivery,
    String operationId,
    String code,
  ) async {
    verifications++;
    if (failVerification) throw StateError('synthetic invalid code');
    return CancellationVerification(
      'verification-secret',
      DateTime.utc(2099),
      confirmationData,
    );
  }

  @override
  Future<CancellationResult> submit(
    CancellationDelivery delivery,
    String operationId,
    String verificationToken,
  ) async {
    submissions++;
    if (loseResponse) throw StateError('synthetic timeout');
    return result;
  }

  @override
  Future<CancellationResult> lookup(
    CancellationDelivery delivery,
    String operationId,
  ) async {
    queries++;
    if (failQuery) throw StateError('synthetic network');
    return notSubmitted
        ? const CancellationResult('', 'NOT_SUBMITTED', null)
        : result;
  }
}
