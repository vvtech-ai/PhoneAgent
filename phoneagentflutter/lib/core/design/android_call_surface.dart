import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'page_route_visibility.dart';

/// Owns only the Android window presentation while a call surface is visible.
/// Content keeps its existing SafeArea; system insets are never added here.
class AndroidCallSurface extends StatefulWidget {
  const AndroidCallSurface({
    super.key,
    required this.backgroundColor,
    required this.child,
    this.ownsScaffold = true,
  });

  final Color backgroundColor;
  final Widget child;
  // Task calls are overlays; translation calls already own their Scaffold.
  final bool ownsScaffold;

  static bool applies(BuildContext context) =>
      !kIsWeb && Theme.of(context).platform == TargetPlatform.android;

  @override
  State<AndroidCallSurface> createState() => _AndroidCallSurfaceState();
}

class _AndroidCallSurfaceState extends State<AndroidCallSurface> {
  final _owner = Object();
  PageRouteVisibilityObserver? _visibility;
  ModalRoute<dynamic>? _route;
  bool _android = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _android = AndroidCallSurface.applies(context);
    _route = ModalRoute.of(context);
    final visibility = context
        .dependOnInheritedWidgetOfExactType<PageRouteVisibilityScope>()
        ?.observer;
    if (!identical(visibility, _visibility)) {
      _visibility?.removeListener(_sync);
      _visibility = visibility;
      _visibility?.addListener(_sync);
    }
    _sync();
  }

  void _sync() {
    // PopupRoutes do not change the visible business page. Standalone previews
    // without the app's observer retain their lease until they are disposed.
    final visible = _visibility == null || _route == null
        ? true
        : identical(_visibility!.currentPage, _route);
    _CallWindowMode.update(_owner, _android && visible);
  }

  @override
  void dispose() {
    _visibility?.removeListener(_sync);
    _CallWindowMode.update(_owner, false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_android) return widget.child;
    return widget.ownsScaffold
        ? Scaffold(backgroundColor: widget.backgroundColor, body: widget.child)
        : ColoredBox(color: widget.backgroundColor, child: widget.child);
  }
}

/// This app otherwise uses FlutterActivity's visible system-bars baseline.
/// Keep changes page-scoped rather than changing the global theme or Activity.
abstract final class _CallWindowMode {
  static final _owners = <Object>{};
  static Future<void>? _pending;
  static int _revision = 0;

  static void update(Object owner, bool active) {
    final changed = active ? _owners.add(owner) : _owners.remove(owner);
    if (!changed) return;
    final revision = ++_revision;
    final operation = (_pending ?? Future<void>.value()).then((_) async {
      if (revision != _revision) return;
      try {
        if (_owners.isNotEmpty) {
          await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        } else {
          await SystemChrome.setEnabledSystemUIMode(
            SystemUiMode.manual,
            overlays: SystemUiOverlay.values,
          );
        }
      } catch (error, stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'Android call window presentation',
          ),
        );
      }
    });
    _pending = operation;
    unawaited(
      operation.whenComplete(() {
        if (identical(_pending, operation)) _pending = null;
      }),
    );
  }
}
