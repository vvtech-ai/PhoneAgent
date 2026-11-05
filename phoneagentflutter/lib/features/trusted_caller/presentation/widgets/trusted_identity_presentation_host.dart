import 'package:flutter/material.dart';
import '../../domain/trusted_incoming_identity.dart';
import '../pages/trusted_identity_credentials_page.dart';

/// Owns only the credentials route; business routes retain their navigation.
class TrustedIdentityPresentationHost extends StatefulWidget {
  const TrustedIdentityPresentationHost({
    required this.navigatorKey,
    required this.identity,
    required this.onDismiss,
    required this.child,
    this.onDiagnostic,
    super.key,
  });
  final GlobalKey<NavigatorState> navigatorKey;
  final TrustedIncomingIdentity? identity;
  final ValueChanged<String> onDismiss;
  final Widget child;
  final ValueChanged<String>? onDiagnostic;

  @override
  State<TrustedIdentityPresentationHost> createState() => _HostState();
}

class _HostState extends State<TrustedIdentityPresentationHost>
    with WidgetsBindingObserver {
  MaterialPageRoute<void>? _route;
  ValueNotifier<TrustedIncomingIdentity>? _values;
  bool _scheduled = false;
  bool _foreground = true;
  String? _lastDiagnostic;
  void _trace(String code) {
    final key = '$code:${widget.identity?.presentationId}';
    if (_lastDiagnostic == key) return;
    _lastDiagnostic = key;
    widget.onDiagnostic?.call(code);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _schedule();
  }

  @override
  void didUpdateWidget(TrustedIdentityPresentationHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigatorKey != widget.navigatorKey) _removeOwnedRoute();
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) _schedule();
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _synchronize();
    });
  }

  void _removeOwnedRoute() {
    final route = _route;
    _route = null;
    _values = null;
    if (route != null && route.isActive) {
      _trace('IOS_PRESENTATION_CLEARED');
      route.navigator?.removeRoute(route);
    }
  }

  void _synchronize() {
    final identity = widget.identity;
    if (identity == null) {
      _removeOwnedRoute();
      return;
    }
    if (!_foreground) {
      _trace('IOS_PRESENTATION_DEFERRED');
      return;
    }
    if (_route != null) {
      if (!_route!.isActive) {
        _schedule();
        return;
      }
      _values!.value = identity;
      return;
    }
    final navigator = widget.navigatorKey.currentState;
    if (navigator == null || !navigator.mounted) return;
    final values = ValueNotifier(identity);
    final route = MaterialPageRoute<void>(
      fullscreenDialog: true,
      settings: const RouteSettings(name: 'trusted-identity-credentials'),
      builder: (_) => ValueListenableBuilder<TrustedIncomingIdentity>(
        valueListenable: values,
        builder: (context, value, _) => TrustedIdentityCredentialsPage(
          identity: value,
          onBack: () {
            // A retained callback must belong to this current presentation.
            if (!mounted ||
                !identical(_values, values) ||
                _route?.isCurrent != true ||
                values.value.presentationId != value.presentationId ||
                widget.identity?.presentationId != value.presentationId) {
              return;
            }
            _trace('IOS_PRESENTATION_DISMISSED');
            widget.onDismiss(value.presentationId);
            _removeOwnedRoute();
          },
        ),
      ),
    );
    _route = route;
    _values = values;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(_route, route) && route.isCurrent) {
        _trace('IOS_PRESENTED');
      }
    });
    navigator.push(route).then((_) {
      if (mounted && identical(_route, route)) {
        _route = null;
        _values = null;
        widget.onDismiss(values.value.presentationId);
      }
      // Route transitions can retain its widget after the popped future.
      route.completed.then((_) => values.dispose());
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final route = _route;
    _route = null;
    _values = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route != null && route.isActive) route.navigator?.removeRoute(route);
    });
    super.dispose();
  }
}
