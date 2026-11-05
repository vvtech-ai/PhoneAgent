import 'dart:async';
import 'package:flutter/material.dart';
import '../core/design/native_notice.dart';
import '../features/auth/presentation/controller/session_controller.dart';

/// Removes every page and modal before account-bound providers are refreshed.
/// A frame acknowledgement, not a timed delay, guarantees their subscriptions
/// have been unmounted. Disposing this host also acknowledges that release.
class SessionNavigationHost extends StatefulWidget {
  const SessionNavigationHost({
    super.key,
    required this.session,
    required this.epoch,
    required this.child,
    this.onReleased,
    this.releasePlaceholder,
  });
  final SessionController session;
  final int? epoch;
  final Widget child;
  final Future<void> Function()? onReleased;
  final Widget? releasePlaceholder;

  @override
  State<SessionNavigationHost> createState() => _SessionNavigationHostState();
}

class _SessionNavigationHostState extends State<SessionNavigationHost> {
  late void Function() _remove;
  Completer<void>? _pending;
  Future<void>? _releaseFuture;
  bool _hidden = false;

  @override
  void initState() {
    super.initState();
    _remove = widget.session.addReleaseListener(_release);
  }

  Future<void> _release() {
    if (_releaseFuture case final release?) return release;
    dismissNativeNotice();
    final pending = _pending = Completer<void>();
    final cleanup = widget.onReleased;
    final release = _releaseFuture = pending.future.then(
      (_) => cleanup?.call(),
    );
    setState(() => _hidden = true);
    return release.whenComplete(() {
      if (identical(_pending, pending)) {
        _pending = null;
        _releaseFuture = null;
      }
    });
  }

  @override
  void didUpdateWidget(SessionNavigationHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      _remove();
      _remove = widget.session.addReleaseListener(_release);
    }
    if (oldWidget.epoch != widget.epoch ||
        oldWidget.session != widget.session) {
      _hidden = false;
    }
  }

  @override
  void dispose() {
    dismissNativeNotice();
    _remove();
    final pending = _pending;
    if (pending != null && !pending.isCompleted) pending.complete();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hidden) {
      return ScaffoldMessenger(
        key: ValueKey(widget.epoch),
        child: widget.child,
      );
    }
    final pending = _pending;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (pending != null && !pending.isCompleted) pending.complete();
    });
    return widget.releasePlaceholder ?? const SizedBox.expand();
  }
}
