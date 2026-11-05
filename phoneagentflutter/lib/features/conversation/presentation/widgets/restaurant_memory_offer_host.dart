import 'package:flutter/material.dart';

/// Invisible presentation effect. No form, choice control or memory write API.
class RestaurantMemoryOfferHost extends StatefulWidget {
  const RestaurantMemoryOfferHost({
    super.key,
    required this.hasOffer,
    required this.isCurrent,
    required this.onShown,
    required this.child,
  });
  final bool hasOffer;
  final bool Function() isCurrent;
  final Future<bool> Function(bool Function() isVisible) onShown;
  final Widget child;
  @override
  State<RestaurantMemoryOfferHost> createState() => _OfferHostState();
}

class _OfferHostState extends State<RestaurantMemoryOfferHost>
    with WidgetsBindingObserver {
  bool _scheduled = false;
  bool get _visible =>
      mounted &&
      widget.hasOffer &&
      widget.isCurrent() &&
      ModalRoute.of(context)?.isCurrent == true &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _schedule() {
    if (!widget.hasOffer || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (_visible) widget.onShown(() => _visible);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _schedule();
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }

  @override
  Widget build(BuildContext context) {
    ModalRoute.of(context);
    _schedule();
    return widget.child;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
