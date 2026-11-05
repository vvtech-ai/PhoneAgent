import '../../../../core/diagnostics/diagnostic_journal.dart';
import 'diagnostic_journal_factory_web.dart'
    if (dart.library.io) 'diagnostic_journal_factory_io.dart'
    as platform;

DiagnosticJournal createDiagnosticJournal(String scope) =>
    platform.createDiagnosticJournal(scope);
