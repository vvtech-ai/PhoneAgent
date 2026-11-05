import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/diagnostics/native_crash_importer.dart';
import '../features/app_logs/data/device_native_crash_port.dart';
import 'diagnostics_providers.dart';

final nativeCrashPortProvider = Provider<NativeCrashPort?>(
  (ref) =>
      !kIsWeb &&
          const {
            TargetPlatform.android,
            TargetPlatform.iOS,
          }.contains(defaultTargetPlatform)
      ? const DeviceNativeCrashPort()
      : null,
);

final nativeCrashImporterProvider = Provider<NativeCrashImporter?>((ref) {
  final port = ref.watch(nativeCrashPortProvider);
  if (port == null) return null;
  final importer = NativeCrashImporter(port);
  ref.onDispose(importer.close);
  return importer;
});

/// A normal-entry-only observer; previews never mount this host.
class NativeCrashHost extends ConsumerStatefulWidget {
  const NativeCrashHost({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<NativeCrashHost> createState() => _NativeCrashHostState();
}

class _NativeCrashHostState extends ConsumerState<NativeCrashHost>
    with WidgetsBindingObserver {
  NativeCrashImporter? _importer;
  ProviderSubscription<String>? _scope;

  @override
  void initState() {
    super.initState();
    _importer = ref.read(nativeCrashImporterProvider);
    if (_importer == null) return;
    WidgetsBinding.instance.addObserver(this);
    _scope = ref.listenManual(
      diagnosticStorageScopeProvider,
      (_, value) => _activate(value),
      fireImmediately: true,
    );
  }

  void _activate(String scope) {
    try {
      // A scope listener can run before dependents are invalidated. Resolve
      // explicitly by its value, never through the current-account alias.
      final journal = ref.read(diagnosticJournalByScopeProvider(scope));
      unawaited(_importer?.activate(nativeCrashScope(scope), journal));
    } catch (_) {
      /* Diagnostics cannot block startup or account transitions. */
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _activate(ref.read(diagnosticStorageScopeProvider));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scope?.close();
    // The provider is also used by upload preparation. Release binding here,
    // without closing an importer still owned by the application container.
    unawaited(_importer?.port.bind(null).catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
