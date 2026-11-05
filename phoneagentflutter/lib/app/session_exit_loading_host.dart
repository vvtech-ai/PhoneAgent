import 'package:flutter/foundation.dart' show kDebugMode;
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'session_exit_snapshot.dart';
import 'package:flutter/material.dart';
import '../core/design/native_loading_overlay.dart';
import '../core/design/native_page_background.dart';
import '../features/auth/presentation/controller/session_controller.dart';

/// Presentation only. SessionController still owns permission and resource release.
class SessionExitLoadingHost extends StatefulWidget {
  const SessionExitLoadingHost({
    required this.owner,
    required this.session,
    required this.epoch,
    required this.cleaning,
    required this.child,
    super.key,
  });
  final SessionController owner;
  final SessionState session;
  final int? epoch;
  final bool cleaning;
  final Widget child;
  @override
  State<SessionExitLoadingHost> createState() => _SessionExitLoadingHostState();
}

class _SessionExitLoadingHostState extends State<SessionExitLoadingHost> {
  final _boundary = GlobalKey();
  late final SessionExitSnapshot _snapshot;
  late VoidCallback _remove;
  (String?, int?)? _captureOwner;
  bool _visible = false;
  String? _account;
  int? _epoch;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _snapshot = SessionExitSnapshot(
      onReady: () {
        if (mounted) setState(() {});
      },
    );
    _remove = widget.owner.addListener(_observe, fireImmediately: false);
    _sync();
  }

  @override
  void didUpdateWidget(SessionExitLoadingHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.owner != widget.owner) {
      _remove();
      _snapshot.clear();
      _captureOwner = null;
      _remove = widget.owner.addListener(_observe, fireImmediately: false);
    }
    _sync();
  }

  // Runs synchronously on invalidation, before the old router is rebuilt/painted.
  void _observe(SessionState state) {
    if (state.businessBlocked &&
        state.invalidationReason != null &&
        widget.owner.invalidationCleanupRunning) {
      final owner = (state.session?.accountId, widget.owner.identityEpoch);
      if (_captureOwner != owner) {
        _captureOwner = owner;
        _snapshot.begin(_captureFrame);
      }
    } else if (state.phase != SessionPhase.signedOut) {
      _captureOwner = null;
      _snapshot.clear();
    }
  }

  Future<ui.Image?> _captureFrame() {
    final boundary = _boundary.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary ||
        (kDebugMode && boundary.debugNeedsPaint) ||
        !boundary.hasSize ||
        boundary.size.isEmpty) {
      return Future.value(null);
    }
    var supported = true;
    var nodes = 0;
    void inspect(RenderObject render) {
      if (!supported) return;
      if (++nodes > 10000 ||
          render is PlatformViewRenderBox ||
          render is RenderUiKitView ||
          render is TextureBox) {
        supported = false;
        return;
      }
      render.visitChildren(inspect);
    }

    inspect(boundary);
    if (!supported) return Future.value(null);
    final pixels = boundary.size.width * boundary.size.height;
    final ratio = math.min(
      View.of(context).devicePixelRatio,
      math.sqrt(1900000 / pixels),
    );
    return boundary.toImage(pixelRatio: ratio);
  }

  @override
  void dispose() {
    _remove();
    _snapshot.dispose();
    super.dispose();
  }

  void _sync() {
    final state = widget.session;
    if (state.businessBlocked && state.invalidationReason != null) {
      final visible = widget.cleaning;
      if (_visible != visible ||
          _account != state.session?.accountId ||
          _epoch != widget.epoch) {
        _generation++;
      }
      if (!visible) _snapshot.clear();
      _visible = visible;
      _account = state.session?.accountId;
      _epoch = widget.epoch;
      return;
    }
    if (_visible && state.phase == SessionPhase.signedOut) return;
    if (_visible) _generation++;
    _visible = false;
    _captureOwner = null;
    _snapshot.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (_visible && widget.session.phase == SessionPhase.signedOut) {
      final generation = _generation;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            generation != _generation ||
            !_visible ||
            widget.session.phase != SessionPhase.signedOut) {
          return;
        }
        setState(() {
          _visible = false;
          _generation++;
          _captureOwner = null;
          _snapshot.clear();
        });
      });
    }
    return PopScope(
      canPop: !_visible,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeFocus(
            excluding: _visible,
            child: ExcludeSemantics(
              excluding: _visible,
              child: IgnorePointer(
                ignoring: _visible,
                child: RepaintBoundary(key: _boundary, child: widget.child),
              ),
            ),
          ),
          if (_visible)
            Positioned.fill(
              child: BlockSemantics(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const NativePageBackground(
                      key: Key('forced-session-exit-surface'),
                      child: SizedBox.expand(),
                    ),
                    if (_snapshot.image case final image?)
                      RawImage(
                        key: const Key('forced-session-exit-image'),
                        image: image,
                        fit: BoxFit.fill,
                      ),
                    const NativeLoadingOverlay(),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
