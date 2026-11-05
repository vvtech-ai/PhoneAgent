import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/dial_recent_providers.dart';
import '../../domain/dial_recent_call.dart';
import 'dial_recent_list.dart';

class DialRecentHost extends ConsumerStatefulWidget {
  const DialRecentHost({
    super.key,
    required this.query,
    required this.onSelect,
    this.enabled = true,
  });
  final String query;
  final ValueChanged<DialRecentCall> onSelect;
  final bool enabled;
  @override
  ConsumerState<DialRecentHost> createState() => _DialRecentHostState();
}

class _DialRecentHostState extends ConsumerState<DialRecentHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted && state == AppLifecycleState.resumed) {
      ref.read(dialRecentProvider.notifier).load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dialRecentProvider);
    return widget.query.isEmpty
        ? DialRecentList(
            state: state,
            nativeLayout: true,
            enabled: widget.enabled,
            onSelect: widget.onSelect,
            onRetry: () => ref.read(dialRecentProvider.notifier).load(),
          )
        : const SizedBox.shrink();
  }
}
