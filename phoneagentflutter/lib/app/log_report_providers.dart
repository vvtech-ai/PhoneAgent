import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/account_session.dart';
import '../features/app_logs/data/zip_log_repository.dart';
import '../features/app_logs/domain/app_log_report.dart';
import '../features/app_logs/domain/format_device_environment.dart';
import '../features/auth/presentation/controller/auth_providers.dart';
import 'business_providers.dart';
import 'diagnostics_providers.dart';
import 'native_crash_host.dart';
import '../features/app_logs/data/device_native_crash_port.dart';
import '../features/app_logs/presentation/controller/log_report_controller.dart';

final logEntryControllerProvider =
    StateNotifierProvider.autoDispose<LogReportController, LogReportState>((
      ref,
    ) {
      ref.watch(loginEpochProvider);
      return LogReportController(ref.watch(logReportRepositoryProvider));
    });

/// Composition boundary; normal routes always retain the authenticated uploader.
final logReportRepositoryProvider = Provider.autoDispose<AppLogRepository>((
  ref,
) {
  ref.watch(loginEpochProvider);
  final session = ref.read(sessionControllerProvider.notifier);
  final owner = session.credentials;
  if (owner == null) throw StateError('Log report requires an account');
  final api = ref.watch(accountApiProvider);
  final environment = ref.watch(deviceEnvironmentSourceProvider);
  final deviceSnapshots = Expando<String>('logDeviceSnapshot');
  final journal = ref.watch(diagnosticJournalProvider);
  final scope = nativeCrashScope(ref.watch(diagnosticStorageScopeProvider));
  final crashes = ref.watch(nativeCrashImporterProvider);
  return ZipLogRepository(
    journal,
    readEnvironment: () async {
      if (!owner.sameLogin(session.credentials)) {
        throw ApiFailure.sessionChanged;
      }
      final snapshot = await environment.read();
      if (!owner.sameLogin(session.credentials)) {
        throw ApiFailure.sessionChanged;
      }
      return snapshot;
    },
    beforePrepare: () async {
      if (!owner.sameLogin(session.credentials)) {
        throw ApiFailure.sessionChanged;
      }
      await crashes?.importPending(scope, journal);
      if (!owner.sameLogin(session.credentials)) {
        throw ApiFailure.sessionChanged;
      }
    },
    uploadBundle: (bundle) async {
      if (!owner.sameLogin(session.credentials)) {
        throw ApiFailure.sessionChanged;
      }
      var info = bundle.environment == null
          ? deviceSnapshots[bundle]
          : formatDeviceEnvironment(bundle.environment!);
      if (info == null) {
        info = formatDeviceEnvironment(await environment.read());
        if (!owner.sameLogin(session.credentials)) {
          throw ApiFailure.sessionChanged;
        }
        deviceSnapshots[bundle] = info;
      }
      await ApiLogUploader(api, owner.accountId, info).upload(bundle);
    },
  );
});
