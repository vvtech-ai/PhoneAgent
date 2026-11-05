import '../../../../core/design/native_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/app_update_providers.dart';
import '../../domain/startup_update.dart';
import '../controller/startup_update_controller.dart';
import '../pages/update_install_route.dart';
import 'startup_update_dialog.dart';
import 'ios_update_dialog.dart';

/// Owns only this session's modal routes; never pops unrelated app navigation.
class StartupUpdateHost extends ConsumerStatefulWidget {
  const StartupUpdateHost({
    super.key,
    required this.child,
    this.previewControls,
    this.installationBuilder,
  });
  final Widget child;
  final Widget? previewControls;
  final Widget Function(StartupUpdateOffer, VoidCallback?)? installationBuilder;
  @override
  ConsumerState<StartupUpdateHost> createState() => _StartupUpdateHostState();
}

class _StartupUpdateHostState extends ConsumerState<StartupUpdateHost> {
  StartupUpdateController? _controller;
  StartupUpdateOffer? _visibleOffer;
  NavigatorState? _navigator;
  Route<void>? _dialog, _install;
  bool _scheduled = false;
  final _installing = ValueNotifier<bool>(false);

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(startupUpdateSupportedProvider)) return widget.child;
    ref.watch(startupUpdateControllerProvider);
    _controller = ref.watch(startupUpdateControllerProvider.notifier);
    if (!_scheduled) {
      _scheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduled = false;
        if (!mounted) return;
        final controller = _controller!;
        controller.start();
        final notice = controller.takeNotice();
        if (notice.isNotEmpty) {
          showNativeNotice(
            context,
            notice,
            duration: const Duration(seconds: 4),
          );
        }
        _synchronize(ref.read(startupUpdateControllerProvider).offer);
      });
    }
    return widget.child;
  }

  void _synchronize(StartupUpdateOffer? offer) {
    if (identical(offer, _visibleOffer)) return;
    _visibleOffer = offer;
    _removeOwnedRoutes();
    _installing.value = false;
    if (offer == null) return;
    _navigator = Navigator.of(context);
    if (offer.recovered) {
      _openInstall(offer);
      return;
    }
    final container = ProviderScope.containerOf(context);
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UncontrolledProviderScope(
        container: container,
        child: ValueListenableBuilder<bool>(
          valueListenable: _installing,
          builder: (_, installing, __) => offer.release.sourceType == 1
              ? IosUpdateDialog(
                  offer: offer,
                  open: ref.read(iosUpdateLinkPortProvider).open,
                  onLater: () => _controller?.dismiss(),
                  onRefresh: () async {
                    await _controller?.refresh();
                  },
                )
              : installing
              ? _installation(offer)
              : StartupUpdateDialog(
                  offer: offer,
                  previewControls: widget.previewControls,
                  onLater: () => _controller?.dismiss(),
                  onInstall: () => _openInstall(offer),
                ),
        ),
      ),
    );
    _dialog = route;
    _navigator!.push(route).then((_) {
      if (mounted &&
          identical(_visibleOffer, offer) &&
          identical(_dialog, route)) {
        _dialog = null;
        if (_install == null) _controller?.dismiss();
      }
    });
  }

  void _openInstall(StartupUpdateOffer offer) {
    if (!mounted || !identical(_visibleOffer, offer) || _install != null) {
      return;
    }
    if (_dialog != null) {
      _installing.value = true;
      return;
    }
    final container = ProviderScope.containerOf(context);
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UncontrolledProviderScope(
        container: container,
        child: _installation(offer),
      ),
    );
    _install = route;
    _navigator!.push(route).then((_) {
      if (mounted &&
          identical(_visibleOffer, offer) &&
          identical(_install, route)) {
        _install = null;
        _controller?.dismiss();
      }
    });
  }

  Widget _installation(StartupUpdateOffer offer) {
    final VoidCallback? refresh = offer.release.apkUrl.isEmpty
        ? () => _controller?.refresh()
        : null;
    return widget.installationBuilder?.call(offer, refresh) ??
        UpdateInstallRoute(
          launch: (app: offer.app, release: offer.release),
          onRefresh: refresh,
          dialog: true,
          autoStart: !offer.recovered,
        );
  }

  void _removeOwnedRoutes() {
    final routes = [_install, _dialog];
    _install = null;
    _dialog = null;
    for (final route in routes) {
      if (route != null && route.isActive && _navigator?.mounted == true) {
        _navigator!.removeRoute(route);
      }
    }
  }

  @override
  void dispose() {
    final navigator = _navigator, routes = [_install, _dialog];
    _install = null;
    _dialog = null;
    _visibleOffer = null;
    _controller = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final route in routes) {
        if (route != null && route.isActive && navigator?.mounted == true) {
          navigator!.removeRoute(route);
        }
      }
      _installing.dispose();
    });
    super.dispose();
  }
}
