import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/phone_agent_app.dart' show appRouterProvider;
import 'package:phone_agent/app/call_recording_providers.dart';
import 'package:phone_agent/app/feedback_providers.dart';
import 'package:phone_agent/app/task_rating_providers.dart';
import 'package:phone_agent/features/conversation/presentation/controller/preview_call_recording_session.dart';
import 'shell_feedback_ports.dart';

final shellFeedbackPortsProvider = Provider<ShellFeedbackPorts>((ref) {
  ref.watch(loginEpochProvider);
  final ports = ShellFeedbackPorts();
  ref.onDispose(ports.close);
  return ports;
});

/// Only the complete-App MOCK host installs these external ports.
List<Override> shellReceiptOverrides(BuildContext context) => [
  callEvaluationRepositoryProvider.overrideWith(
    (ref) => ref.watch(shellFeedbackPortsProvider),
  ),
  taskRatingRepositoryProvider.overrideWith(
    (ref) => ref.watch(shellFeedbackPortsProvider),
  ),
  taskRatingDraftStoreProvider.overrideWith(
    (ref) => ref.watch(shellFeedbackPortsProvider),
  ),
  conversationRecordingsProvider.overrideWith((ref, host) {
    ref.watch(loginEpochProvider);
    var closed = false;
    final manager = createPreviewCallRecordings(() async {
      if (closed || !context.mounted) return false;
      final navigatorContext = ref
          .read(appRouterProvider)
          .routerDelegate
          .navigatorKey
          .currentContext;
      if (navigatorContext == null || !navigatorContext.mounted) return false;
      return await showDialog<bool>(
            context: navigatorContext,
            builder: (dialog) => AlertDialog(
              title: const Text('MOCK · 保存本次录音'),
              content: const Text('仅模拟保存位置，不播放声音、不读取或写入真实文件。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialog, false),
                  child: const Text('取消保存'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialog, true),
                  child: const Text('模拟保存'),
                ),
              ],
            ),
          ) ??
          false;
    });
    ref.onDispose(() {
      closed = true;
      manager.dispose();
    });
    return manager;
  }),
];
