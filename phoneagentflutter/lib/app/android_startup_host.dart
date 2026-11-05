import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/presentation/controller/auth_providers.dart';
import '../features/auth/presentation/controller/session_controller.dart';

/// Keeps Android's system splash until the initial local session is resolved.
class AndroidStartupHost extends ConsumerStatefulWidget {
  const AndroidStartupHost({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<AndroidStartupHost> createState() => _AndroidStartupHostState();
}

class _AndroidStartupHostState extends ConsumerState<AndroidStartupHost> {
  bool _holding = false;
  bool _releaseScheduled = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    WidgetsBinding.instance.deferFirstFrame();
    _holding = true;
    ref.listenManual(sessionControllerProvider, (_, state) {
      if (state.phase == SessionPhase.restoring || _releaseScheduled) return;
      _releaseScheduled = true;
      // Deferred frames still build/layout: reveal the resolved target page,
      // rather than sending the previous restoring frame to the engine.
      WidgetsBinding.instance.addPostFrameCallback((_) => _release());
      WidgetsBinding.instance.ensureVisualUpdate();
    }, fireImmediately: true);
  }

  void _release() {
    if (!_holding) return;
    _holding = false;
    WidgetsBinding.instance.allowFirstFrame();
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
