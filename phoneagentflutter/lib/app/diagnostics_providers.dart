import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/diagnostics/diagnostic_journal.dart';
import '../features/app_logs/data/diagnostic_journal_factory.dart';
import '../features/app_logs/data/device_environment_channel.dart';
import '../features/app_update/domain/app_update.dart';
import '../features/auth/presentation/controller/auth_providers.dart';
import 'app_providers.dart';

final deviceEnvironmentSourceProvider = Provider(
  (_) => const DeviceEnvironmentChannel(),
);

// Keep one journal per storage namespace while the app is alive, so two login
// epochs of the same account never concurrently overwrite the same journal.
final diagnosticJournalFactoryProvider =
    Provider<DiagnosticJournal Function(String)>(
      (ref) => createDiagnosticJournal,
    );
final diagnosticJournalByScopeProvider =
    Provider.family<DiagnosticJournal, String>((ref, scope) {
      final journal = ref.watch(diagnosticJournalFactoryProvider)(scope);
      ref.onDispose(journal.close);
      return journal;
    });
final diagnosticStorageScopeProvider = Provider<String>((ref) {
  final config = ref.watch(appConfigProvider);
  ref.watch(sessionControllerProvider);
  final owner =
      ref.read(sessionControllerProvider.notifier).credentials?.accountId ??
      'signed-out';
  return '${config.environment?.name}|${config.apiBaseUri}|$owner';
});
final diagnosticJournalProvider = Provider<DiagnosticJournal>((ref) {
  return ref.watch(
    diagnosticJournalByScopeProvider(ref.watch(diagnosticStorageScopeProvider)),
  );
});
String diagnosticDeviceInfo(InstalledApp app) =>
    'Flutter ${kIsWeb ? 'web' : defaultTargetPlatform.name} / '
    '${app.versionName}(${app.versionCode})';
