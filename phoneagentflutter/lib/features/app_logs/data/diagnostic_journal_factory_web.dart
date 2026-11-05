import '../../../../core/diagnostics/diagnostic_journal.dart';
import 'secure_diagnostic_store.dart';

// Web is a development surface, not a filesystem/native-crash collector.
DiagnosticJournal createDiagnosticJournal(String scope) =>
    DiagnosticJournal(SecureDiagnosticStore(scope));
