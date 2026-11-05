import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'shell_network_error_ports.dart';

/// Synthetic controls outside the production navigator; pages stay unchanged.
class ShellErrorControls extends ConsumerWidget {
  const ShellErrorControls({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ports = ref.watch(shellNetworkErrorPortsProvider);
    return Column(
      verticalDirection: VerticalDirection.up,
      children: [
        Expanded(child: child),
        Material(
          color: const Color(0xfffff3cd),
          child: ValueListenableBuilder(
            valueListenable: ports.revision,
            builder: (_, __, ___) => Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton(
                  onPressed: () => ports.setOnline(ports.offline),
                  child: Text(ports.offline ? 'MOCK：恢复网络' : 'MOCK：断开网络'),
                ),
                Text(
                  '状态请求 ${ports.sent.length} · ${ports.offline ? "离线" : "在线"}',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
