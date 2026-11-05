import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/diagnostics/diagnostic_event.dart';
import '../core/diagnostics/runtime_diagnostic_hooks.dart';
import 'diagnostics_providers.dart';
import 'native_crash_host.dart';

/// Installed only by the normal app entry point, not isolated preview targets.
class RuntimeDiagnosticsHost extends ConsumerStatefulWidget {
  const RuntimeDiagnosticsHost({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<RuntimeDiagnosticsHost> createState() =>
      _RuntimeDiagnosticsHostState();
}

class _RuntimeDiagnosticsHostState
    extends ConsumerState<RuntimeDiagnosticsHost> {
  late final RuntimeDiagnosticHooks _hooks;

  @override
  void initState() {
    super.initState();
    _hooks = RuntimeDiagnosticHooks.install(_record);
  }

  void _record(DiagnosticEvent event) {
    if (!mounted) return;
    try {
      // Resolve synchronously at occurrence, not after storage or an account
      // switch. Never hold an old account's sink for subsequent errors.
      final journal = ref.read(diagnosticJournalProvider);
      journal.record(event);
      unawaited(journal.flush().catchError((Object _) {}));
    } catch (_) {
      // Provider/container/storage failure must not replace the original error.
    }
  }

  @override
  void dispose() {
    _hooks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => NativeCrashHost(child: widget.child);
}
