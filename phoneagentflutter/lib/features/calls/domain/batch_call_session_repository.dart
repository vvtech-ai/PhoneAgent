import 'call_session.dart';

/// Binds observation and stop to the original execution, without call admission.
abstract interface class BatchCallSessionRepositoryFactory {
  CallSessionRepository forBatch(
    String sessionId,
    String batchId,
    String attemptId,
  );
}
