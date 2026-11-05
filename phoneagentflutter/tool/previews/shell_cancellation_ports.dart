import 'package:phone_agent/features/account_cancellation/domain/account_cancellation.dart';

/// Synthetic workbench only; never sends SMS or changes a real account.
class PreviewCancellationGateway implements CancellationGateway {
  @override
  Future<CancellationConfirmation> confirmation() async =>
      CancellationConfirmation(
        'synthetic-confirmation',
        'synthetic-v1',
        'https://example.test/agreement',
        DateTime.utc(2026, 11, 10),
      );
  @override
  Future<CancellationDelivery> send(
    CancellationConfirmation confirmation,
    String operationId,
  ) async => const CancellationDelivery(
    'synthetic-challenge',
    'synthetic-query',
    '138****0000',
    60,
  );
  @override
  Future<CancellationVerification> verify(
    CancellationDelivery delivery,
    String operationId,
    String code,
  ) async => CancellationVerification(
    'synthetic-verification',
    DateTime.utc(2099),
    await confirmation(),
  );

  @override
  Future<CancellationResult> submit(
    CancellationDelivery delivery,
    String operationId,
    String verificationToken,
  ) async => CancellationResult(
    'synthetic-application',
    'PENDING',
    DateTime.utc(2026, 11, 10),
  );
  @override
  Future<CancellationResult> lookup(
    CancellationDelivery delivery,
    String operationId,
  ) async => CancellationResult(
    'synthetic-application',
    'PENDING',
    DateTime.utc(2026, 11, 10),
  );
}
