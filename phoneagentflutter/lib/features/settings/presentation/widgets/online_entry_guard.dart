import '../../../../core/design/native_business_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/online_entry_providers.dart';
import '../../domain/network_availability.dart';
import '../controller/online_entry_controller.dart';

/// UI adapter to the shared admission controller; no network/platform calls.
Future<bool> allowOnlineEntry(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final route = ModalRoute.of(context);
  final attempt = container.read(onlineEntryControllerProvider).begin();
  if (attempt == null) return false;
  try {
    final decision = await attempt.check();
    if (!context.mounted || route?.isCurrent == false) return false;
    if (decision.canAttempt) return true;
    if (decision == OnlineEntryDecision.cancelled) return false;
    await showDialog<void>(
      context: context,
      builder: (_) => UncontrolledProviderScope(
        container: container,
        child: _NetworkBlocker(attempt: attempt, initial: decision),
      ),
    );
    // Retry only dismisses, never queues/replays the original action.
    return false;
  } finally {
    attempt.close();
  }
}

class _NetworkBlocker extends StatefulWidget {
  const _NetworkBlocker({required this.attempt, required this.initial});
  final OnlineEntryAttempt attempt;
  final OnlineEntryDecision initial;
  @override
  State<_NetworkBlocker> createState() => _NetworkBlockerState();
}

class _NetworkBlockerState extends State<_NetworkBlocker> {
  bool _retried = false, _checking = false;
  late OnlineEntryDecision _decision = widget.initial;

  Future<void> _retry() async {
    if (_checking) return;
    setState(() => _checking = true);
    final decision = await widget.attempt.check();
    if (!mounted) return;
    if (decision.canAttempt || decision == OnlineEntryDecision.cancelled) {
      Navigator.pop(context);
    } else {
      setState(() {
        _checking = false;
        _retried = true;
        _decision = decision;
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) widget.attempt.close();
    },
    child: NativeBusinessDialog(
      title: '无网络连接',
      message: _checking
          ? '正在检查系统网络状态…'
          : _decision == OnlineEntryDecision.simulatedOffline
          ? (_retried ? '当前仍为断网模拟，可在开发者功能切换' : '请检查网络设置后重试（当前为断网模拟）')
          : '系统当前没有可用网络，请检查网络设置后重试',
      dismissLabel: '关闭',
      onDismiss: () => Navigator.pop(context),
      confirmLabel: _checking ? '检查中' : '重试',
      onConfirm: _checking ? null : _retry,
    ),
  );
}
