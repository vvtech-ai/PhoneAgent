import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/trusted_caller_providers.dart';
import '../../../../core/design/native_notice.dart';
import '../../domain/trusted_caller.dart';
import '../controller/trusted_caller_controller.dart';
import 'trusted_caller_introduction_page.dart';

/// Coordinates one SDK presentation while the original settings page stays visible.
class TrustedCallerSettingsEntry extends ConsumerStatefulWidget {
  const TrustedCallerSettingsEntry({super.key, required this.builder});
  final Widget Function(BuildContext context, VoidCallback onOpen) builder;

  @override
  ConsumerState<TrustedCallerSettingsEntry> createState() => _EntryState();
}

class _EntryState extends ConsumerState<TrustedCallerSettingsEntry> {
  bool _opening = false;
  Route<void>? _guideRoute;
  TrustedCallerOwner? _guideOwner;
  ProviderSubscription<TrustedCallerState>? _subscription;

  bool get _visible => mounted && ModalRoute.of(context)?.isCurrent == true;

  bool _sameOwner(TrustedCallerController controller) =>
      mounted &&
      identical(
        ref.read(trustedCallerControllerProvider.notifier),
        controller,
      ) &&
      ref.read(trustedCallerOwnerProvider)?.matches(controller.owner) == true;

  bool _current(TrustedCallerController controller) =>
      _visible && _sameOwner(controller);

  void _discardGuide() {
    final route = _guideRoute;
    _guideRoute = null;
    _guideOwner = null;
    if (route == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route.isActive) route.navigator?.removeRoute(route);
    });
  }

  Future<void> _showIntroduction(TrustedCallerController controller) async {
    var started = false;
    late final MaterialPageRoute<void> route;
    void close() {
      if (!route.isActive) return;
      final navigator = route.navigator;
      if (route.isCurrent) {
        navigator?.pop();
      } else {
        navigator?.removeRoute(route);
      }
    }

    route = MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => TrustedCallerIntroductionPage(
        onStart: () async {
          if (started || !route.isCurrent || !_sameOwner(controller)) return;
          started = true;
          // Keep the guide underneath SDK, like the native introduction navigation.
          await controller.openEntrySettings();
          close();
        },
        onExit: () {
          if (!started && route.isCurrent) close();
        },
      ),
    );
    _guideRoute = route;
    _guideOwner = controller.owner;
    await Navigator.of(context).push<void>(route);
    if (identical(_guideRoute, route)) {
      _guideRoute = null;
      _guideOwner = null;
    }
  }

  void _feedback(TrustedCallerController controller) {
    if (!_current(controller)) return;
    final error = ref.read(trustedCallerControllerProvider).error;
    if (error.isNotEmpty) showNativeNotice(context, error);
  }

  Future<void> _open() async {
    if (_opening || !_visible) return;
    if (ref.read(trustedCallerOwnerProvider)?.valid != true) {
      showNativeNotice(context, '请先登录并绑定手机号');
      return;
    }
    _opening = true;
    // Only this action holds the presentation provider; no SDK work on page build.
    final subscription = ref.listenManual(trustedCallerControllerProvider, (
      _,
      _,
    ) {
      final owner = _guideOwner;
      if (owner != null &&
          ref.read(trustedCallerOwnerProvider)?.matches(owner) != true) {
        _discardGuide();
      }
    });
    _subscription = subscription;
    final controller = ref.read(trustedCallerControllerProvider.notifier);
    try {
      await controller.prepareEntry();
      if (!_current(controller)) return;
      final state = ref.read(trustedCallerControllerProvider);
      if (state.error.isNotEmpty ||
          state.status == TrustedCallerStatus.unavailable) {
        _feedback(controller);
        return;
      }
      if (defaultTargetPlatform == TargetPlatform.iOS &&
          state.needsIntroduction) {
        if (!await controller.markIntroductionSeen() ||
            !mounted ||
            !_current(controller)) {
          _feedback(controller);
          return;
        }
        await _showIntroduction(controller);
      } else {
        if (!_current(controller)) return;
        await controller.openEntrySettings();
      }
      _feedback(controller);
      if (defaultTargetPlatform == TargetPlatform.iOS &&
          _current(controller) &&
          ref.read(trustedCallerControllerProvider).error.isEmpty) {
        // Only iOS completes on dismissal. Android merely acknowledges launch.
        await controller.refresh();
      }
    } finally {
      if (identical(_subscription, subscription)) {
        _subscription = null;
        subscription.close();
      }
      _opening = false;
    }
  }

  @override
  void dispose() {
    _discardGuide();
    _subscription?.close();
    _subscription = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _open);
}
