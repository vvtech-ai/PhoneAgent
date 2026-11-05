import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/diagnostics/diagnostic_event.dart';
import '../core/network/account_session.dart';
import '../features/auth/presentation/controller/auth_providers.dart';
import '../features/conversation/data/recovery/api_task_error_status_gateway.dart';
import '../features/conversation/data/recovery/secure_task_error_status_store.dart';
import '../features/conversation/domain/recovery/task_error_status_sync.dart';
import '../features/conversation/domain/recovery/task_error_network_recovery.dart';
import '../features/settings/domain/network_availability_events.dart';
import 'app_providers.dart';
import 'business_providers.dart';
import 'diagnostics_providers.dart';
import 'online_entry_providers.dart';

final taskErrorNetworkRecoveryProvider =
    Provider.autoDispose<TaskErrorNetworkRecovery>((ref) {
      ref.watch(loginEpochProvider);
      final session = ref.watch(sessionControllerProvider.notifier);
      final owner = session.credentials;
      var disposed = false;
      bool current() =>
          !disposed && owner?.sameLogin(session.credentials) == true;
      final recovery = TaskErrorNetworkRecovery(
        ref.watch(taskErrorStatusSyncProvider),
        owner == null
            ? const NoNetworkAvailabilityEvents()
            : ref.watch(networkAvailabilityEventsProvider),
        isCurrent: current,
      );
      ref.keepAlive();
      ref.onDispose(() {
        disposed = true;
        recovery.close();
      });
      return recovery;
    });

final taskErrorStatusSyncProvider = Provider.autoDispose<TaskErrorStatusSync>((
  ref,
) {
  ref.watch(loginEpochProvider);
  final session = ref.watch(sessionControllerProvider.notifier);
  final owner = session.credentials;
  if (owner == null) throw ApiFailure.signedOut;
  final api = ref.watch(accountApiProvider);
  final config = ref.watch(appConfigProvider);
  final journal = ref.watch(diagnosticJournalProvider);
  var disposed = false;
  bool current() => !disposed && owner.sameLogin(session.credentials);
  final sync = TaskErrorStatusSync(
    store: SecureTaskErrorStatusStore(
      config,
      owner.accountId,
      isCurrent: current,
    ),
    gateway: ApiTaskErrorStatusGateway(api, owner.accountId),
    isCurrent: current,
    observe: (event, command) => emitDiagnostic(
      journal.record,
      DiagnosticEvent(
        operation: switch (event) {
          TaskErrorSyncEvent.persisted || TaskErrorSyncEvent.storageFailed =>
            DiagnosticOperation.taskErrorStatusPersistence,
          _ => DiagnosticOperation.taskErrorStatusSync,
        },
        result: switch (event) {
          TaskErrorSyncEvent.queued => DiagnosticResult.started,
          TaskErrorSyncEvent.storageFailed ||
          TaskErrorSyncEvent.requestFailed => DiagnosticResult.failed,
          _ => DiagnosticResult.succeeded,
        },
        sessionId: command?.sessionId ?? '',
        traceId: command?.commandId ?? '',
      ),
    ),
  );
  // Page disposal must not destroy a status write. Epoch changes still dispose
  // this lease and AccountApi rejects responses/requests from the previous login.
  ref.keepAlive();
  ref.onDispose(() {
    disposed = true;
    sync.close();
  });
  return sync;
});
