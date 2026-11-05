import 'dart:ui' show FlutterView;
import 'package:flutter/material.dart';
import '../../../../core/design/conversation_tokens.dart';

/// Owns presentation scroll placement; it never modifies conversation facts.
class NativeConversationTimeline extends StatefulWidget {
  const NativeConversationTimeline({
    super.key,
    required this.reverse,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(22, 14, 22, 12),
    this.tailRevision,
    this.focusItemKey,
    this.inputRevision,
    this.sentRevision,
  });
  final bool reverse;
  final Object? tailRevision;
  final Object? inputRevision, sentRevision;
  final Key? focusItemKey;
  final List<Widget> children;
  final EdgeInsets padding;

  @override
  State<NativeConversationTimeline> createState() => _TimelineState();
}

class _TimelineState extends State<NativeConversationTimeline>
    with WidgetsBindingObserver {
  final _scroll = ScrollController();
  final _itemKeys = <Key, GlobalKey>{};
  int _placementEpoch = 0;
  bool _followingTail = true;

  double _keyboardInset = 0;
  double _viewKeyboardInset = 0;
  FlutterView? _view;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.focusItemKey != null) _placeTail(animate: false, focus: true);
  }

  @override
  void didChangeMetrics() {
    final view = _view;
    if (view == null) return;
    final inset = view.viewInsets.bottom / view.devicePixelRatio;
    if (inset > _viewKeyboardInset && widget.reverse) {
      _placeTail(animate: false);
    }
    _viewKeyboardInset = inset;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final view = View.of(context);
    if (!identical(_view, view)) {
      _view = view;
      _viewKeyboardInset = view.viewInsets.bottom / view.devicePixelRatio;
    }
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    if (inset > _keyboardInset && widget.reverse) {
      _placeTail(animate: false);
    }
    _keyboardInset = inset;
  }

  @override
  void didUpdateWidget(covariant NativeConversationTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.inputRevision != widget.inputRevision ||
        oldWidget.sentRevision != widget.sentRevision) {
      _placeTail(animate: false);
    } else if (oldWidget.reverse != widget.reverse ||
        oldWidget.focusItemKey != widget.focusItemKey) {
      _placeTail(animate: false, focus: widget.focusItemKey != null);
    } else if (widget.reverse &&
        oldWidget.tailRevision != widget.tailRevision &&
        _followingTail) {
      _placeTail(animate: true);
    }
  }

  void _placeTail({required bool animate, bool focus = false}) {
    _followingTail = !focus;
    final epoch = ++_placementEpoch;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || epoch != _placementEpoch || !_scroll.hasClients) return;
      if (focus && widget.focusItemKey != null) {
        _placeFocusedItem(epoch, animate: animate);
        return;
      }
      final tail = widget.reverse
          ? _scroll.position.minScrollExtent
          : _scroll.position.maxScrollExtent;
      if (animate && !MediaQuery.disableAnimationsOf(context)) {
        _scroll.animateTo(
          tail,
          duration: ConversationTokens.motionDuration,
          curve: Curves.easeOut,
        );
      } else {
        _scroll.jumpTo(tail);
      }
    });
  }

  void _placeFocusedItem(
    int epoch, {
    required bool animate,
    bool reset = true,
  }) {
    if (!mounted || epoch != _placementEpoch || !_scroll.hasClients) return;
    final target = _itemKeys[widget.focusItemKey]?.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        alignment: widget.reverse ? 1 : 0,
        duration: animate && !MediaQuery.disableAnimationsOf(context)
            ? ConversationTokens.motionDuration
            : Duration.zero,
        curve: Curves.easeOut,
      );
      return;
    }
    // A restored card can be beyond ListView's cache. Build one viewport at a
    // time rather than materializing the entire conversation just to find it.
    final position = _scroll.position;
    final next = reset && position.pixels != position.minScrollExtent
        ? position.minScrollExtent
        : (position.pixels + position.viewportDimension)
              .clamp(position.minScrollExtent, position.maxScrollExtent)
              .toDouble();
    if (next == position.pixels) return;
    _scroll.jumpTo(next);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _placeFocusedItem(epoch, animate: animate, reset: false),
    );
  }

  @override
  void dispose() {
    _placementEpoch++;
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.depth == 0 &&
            notification is ScrollUpdateNotification &&
            notification.dragDetails != null) {
          _placementEpoch++;
          _followingTail = widget.reverse
              ? notification.metrics.extentBefore < 48
              : notification.metrics.extentAfter < 48;
        }
        return false;
      },
      child: ListView(
        key: const ValueKey('conversation-timeline'),
        controller: _scroll,
        reverse: widget.reverse,
        shrinkWrap: true,
        padding: widget.padding,
        children: [
          for (final child in widget.children)
            if (child.key != null)
              KeyedSubtree(
                key: _itemKeys.putIfAbsent(child.key!, () => GlobalKey()),
                child: child,
              )
            else
              child,
        ],
      ),
    ),
  );
}
