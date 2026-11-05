import '../../../../core/design/native_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/points_session_providers.dart';
import '../controller/points_session_controller.dart';

/// Mounted for an authenticated epoch. UI forwards lifecycle, never API calls.
class PointsSessionHost extends ConsumerStatefulWidget {
  const PointsSessionHost({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<PointsSessionHost> createState() => _PointsSessionHostState();
}

class _PointsSessionHostState extends ConsumerState<PointsSessionHost>
    with WidgetsBindingObserver {
  PointsSessionController? _controller;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _controller?.setForeground(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.setForeground(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(pointsSessionControllerProvider.notifier);
    if (!identical(_controller, controller)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            !identical(
              controller,
              ref.read(pointsSessionControllerProvider.notifier),
            )) {
          return;
        }
        _controller?.setForeground(false);
        _controller = controller;
        final lifecycle = WidgetsBinding.instance.lifecycleState;
        controller.setForeground(
          lifecycle == null || lifecycle == AppLifecycleState.resumed,
        );
        _showNotices();
      });
    }
    ref.listen(pointsSessionControllerProvider, (_, notices) {
      if (notices.isEmpty) return;
      _showNotices();
    });
    return widget.child;
  }

  void _showNotices() {
    final messages = ref
        .read(pointsSessionControllerProvider.notifier)
        .takeNotices();
    for (final message in messages) {
      showNativeNotice(context, message, duration: const Duration(seconds: 4));
    }
  }
}
