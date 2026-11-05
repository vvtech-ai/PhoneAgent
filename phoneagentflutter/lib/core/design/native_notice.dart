import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'package:flutter/material.dart';

_NativeNoticeQueue? _noticeQueue;

/// Clear all notices, or only notices belonging to one presentation owner.
void dismissNativeNotice({Object? owner}) {
  if (owner == null) {
    _noticeQueue?.clear();
  } else {
    _noticeQueue?.removeOwner(owner);
  }
}

/// Native-style transient notice: navigation remains usable underneath it.
void showNativeNotice(
  BuildContext context,
  String message, {
  Duration duration = const Duration(milliseconds: 1800),
  OverlayState? overlay,
  Object? owner,
  bool centered = false,
}) {
  if (message.isEmpty || !context.mounted) return;
  final hostOverlay = overlay ?? Overlay.of(context);
  if (!hostOverlay.mounted) return;
  if (_noticeQueue?.overlay != hostOverlay) dismissNativeNotice();
  final queue = _noticeQueue ??= _NativeNoticeQueue(hostOverlay);
  queue.add(message, duration, owner, centered);
}

class _NativeNoticeQueue {
  _NativeNoticeQueue(this.overlay);
  final OverlayState overlay;
  final _pending =
      Queue<
        ({String message, Duration duration, Object? owner, bool centered})
      >();
  OverlayEntry? _entry;
  Object? _entryOwner;

  void add(String message, Duration duration, Object? owner, bool centered) {
    _pending.add((
      message: message,
      duration: duration,
      owner: owner,
      centered: centered,
    ));
    _showNext();
  }

  void removeOwner(Object owner) {
    _pending.removeWhere((request) => identical(request.owner, owner));
    final entry = _entry;
    if (entry != null && identical(_entryOwner, owner)) _finish(entry);
  }

  void _showNext() {
    if (!identical(_noticeQueue, this) || _entry != null) return;
    if (!overlay.mounted || _pending.isEmpty) {
      clear();
      return;
    }
    final request = _pending.removeFirst();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _NativeNotice(
        message: request.message,
        centered: request.centered,
        duration: request.duration,
        onDismiss: () => _finish(entry),
        onDisposed: () {
          // Unexpected Overlay destruction must not replay queued notices.
          if (identical(_entry, entry)) clear();
        },
      ),
    );
    _entry = entry;
    _entryOwner = request.owner;
    overlay.insert(entry);
  }

  void _finish(OverlayEntry entry) {
    if (!identical(_entry, entry)) return;
    _entry = null;
    _entryOwner = null;
    entry.remove();
    entry.dispose();
    scheduleMicrotask(_showNext);
  }

  void clear() {
    _pending.clear();
    final entry = _entry;
    _entry = null;
    _entryOwner = null;
    if (identical(_noticeQueue, this)) _noticeQueue = null;
    entry?.remove();
    entry?.dispose();
  }
}

class _NativeNotice extends StatefulWidget {
  const _NativeNotice({
    required this.message,
    required this.centered,
    required this.duration,
    required this.onDismiss,
    required this.onDisposed,
  });
  final String message;
  final bool centered;
  final Duration duration;
  final VoidCallback onDismiss;
  final VoidCallback onDisposed;
  @override
  State<_NativeNotice> createState() => _NativeNoticeState();
}

class _NativeNoticeState extends State<_NativeNotice>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  late final AnimationController _opacity;
  @override
  void initState() {
    super.initState();
    _opacity = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _opacity.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) widget.onDismiss();
    });
    final duration = widget.duration > Duration.zero
        ? widget.duration
        : const Duration(seconds: 1);
    _timer = Timer(duration + const Duration(milliseconds: 180), () {
      if (mounted) _opacity.reverse();
    });
    _opacity.forward();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _opacity.dispose();
    // Parent Overlay may be unmounting for account release; remove afterward.
    scheduleMicrotask(widget.onDisposed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Overlay covers the entire view: keyboard and safe area overlap, not add.
    final bottom = math.max(
      MediaQuery.viewInsetsOf(context).bottom + 16,
      MediaQuery.viewPaddingOf(context).bottom + 96,
    );
    return IgnorePointer(
      child: FadeTransition(
        opacity: _opacity,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: widget.centered ? 0 : bottom),
            child: Align(
              alignment: widget.centered
                  ? Alignment.center
                  : Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: DecoratedBox(
                  key: const ValueKey('nativeNoticeSurface'),
                  decoration: BoxDecoration(
                    color: widget.centered
                        ? const Color(0xE6333333)
                        : const Color(0xFAFFFFFF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFD1D1D1)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F000000),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!widget.centered)
                          Image.asset(
                            'assets/images/auth_brand_logo.png',
                            key: const ValueKey('nativeNoticeBrand'),
                            width: 22,
                            height: 22,
                            fit: BoxFit.contain,
                            excludeFromSemantics: true,
                          ),
                        if (!widget.centered) const SizedBox(width: 8),
                        Flexible(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                for (final part in widget.message.split(
                                  RegExp(r'(?=✦)|(?<=✦)'),
                                ))
                                  TextSpan(
                                    text: part,
                                    style: part == '✦'
                                        ? const TextStyle(
                                            color: Color(0xFFFFC400),
                                          )
                                        : null,
                                  ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              inherit: false,
                              decoration: TextDecoration.none,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: widget.centered
                                  ? Colors.white
                                  : const Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
