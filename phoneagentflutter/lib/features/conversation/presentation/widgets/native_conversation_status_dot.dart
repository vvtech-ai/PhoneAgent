import 'package:flutter/material.dart';

/// Decorative stage feedback; it never starts or reports business activity.
class NativeConversationStatusDot extends StatefulWidget {
  const NativeConversationStatusDot({super.key, required this.completed});
  final bool completed;

  @override
  State<NativeConversationStatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<NativeConversationStatusDot>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final _opacity = Tween<double>(
    begin: 1,
    end: .3,
  ).animate(CurvedAnimation(parent: _pulse, curve: Curves.fastOutSlowIn));
  bool _active = false;
  AppLifecycleState? _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = WidgetsBinding.instance.lifecycleState;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant NativeConversationStatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    _sync();
  }

  void _sync() {
    final next =
        !widget.completed &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.of(context) &&
        (_lifecycle == null || _lifecycle == AppLifecycleState.resumed);
    if (next == _active) return;
    _active = next;
    _pulse.stop();
    _pulse.value = 0;
    if (next) _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: FadeTransition(
      opacity: _opacity,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.completed
              ? const Color(0xFF34C759)
              : const Color(0xFF2196F3),
          shape: BoxShape.circle,
        ),
      ),
    ),
  );
}
