import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/dial_permission_providers.dart';
import '../../../../app/dial_recent_providers.dart';
import '../../../../app/translation_location_providers.dart';
import '../../../../app/translation_providers.dart';
import '../../domain/dial_permission.dart';
import '../controller/dial_permission_controller.dart';
import 'dial_permission_dialog.dart';

class DialPermissionHost extends ConsumerStatefulWidget {
  const DialPermissionHost({
    super.key,
    required this.enabled,
    required this.ready,
    required this.onEnabled,
    required this.builder,
  });
  final bool enabled, ready;
  final ValueChanged<bool> onEnabled;
  final Widget Function(BuildContext, DialPermissionController) builder;
  @override
  ConsumerState<DialPermissionHost> createState() => _DialPermissionHostState();
}

class _DialPermissionHostState extends ConsumerState<DialPermissionHost>
    with WidgetsBindingObserver {
  late final DialPermissionController controller;
  late final VoidCallback _remove;
  bool _dialogOpen = false;
  Route<void>? _dialogRoute;
  NavigatorState? _dialogNavigator;
  DialPermissionState state = const DialPermissionState(
    DialPermissionStage.idle,
  );
  @override
  void initState() {
    super.initState();
    controller = DialPermissionController(
      port: ref.read(dialPermissionPortProvider),
      androidNativeParity:
          !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
      memory: ref.read(dialPermissionMemoryProvider),
      setTranslation: (value) {
        if (mounted) widget.onEnabled(value);
      },
      refreshRegion: () => ref
          .read(translationLocationProvider.notifier)
          .refreshAfterPermission(),
      refreshRecent: () => ref.read(dialRecentProvider.notifier).load(),
      simulatedLocation: () => ref
          .read(translationSetupProvider)
          .value
          .simulatedCountryIso
          .isNotEmpty,
    );
    _remove = controller.addListener((value) {
      state = value;
      if (mounted) {
        setState(() {});
        _showDialog();
      }
    });
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  void _start() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.ready) {
        controller.start(translationEnabled: widget.enabled);
      }
    });
  }

  bool get _needsDialog =>
      state.hasDialog ||
      (!controller.androidNativeParity &&
          state.stage == DialPermissionStage.settings);
  void _showDialog() {
    if (!_needsDialog || _dialogOpen) return;
    _dialogOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_needsDialog) {
        _dialogOpen = false;
        return;
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: .60),
        barrierLabel: '取消位置权限提示',
        builder: (dialogContext) {
          _dialogRoute = ModalRoute.of(dialogContext);
          _dialogNavigator = Navigator.of(dialogContext);
          return DialPermissionDialog(controller: controller);
        },
      );
      _dialogRoute = null;
      _dialogNavigator = null;
      _dialogOpen = false;
      if (mounted && _needsDialog) await controller.cancel();
      if (mounted) _showDialog();
    });
  }

  @override
  void didUpdateWidget(covariant DialPermissionHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.ready && widget.ready) _start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState value) {
    if (value == AppLifecycleState.resumed && mounted) controller.resume();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final route = _dialogRoute, navigator = _dialogNavigator;
    if (route != null && navigator != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigator.mounted && route.isActive) navigator.removeRoute(route);
      });
    }
    _remove();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(translationLocationProvider);
    ref.watch(dialRecentProvider);
    return Stack(
      fit: StackFit.expand,
      children: [
        AbsorbPointer(
          absorbing:
              state.busy ||
              _needsDialog ||
              (controller.androidNativeParity &&
                  state.stage == DialPermissionStage.settings),
          child: widget.builder(context, controller),
        ),
        if (state.busy)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(child: LinearProgressIndicator()),
          ),
        if (!_needsDialog && state.message.isNotEmpty)
          Positioned(
            left: 16,
            right: 16,
            top: 8,
            child: SafeArea(
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(state.message),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
