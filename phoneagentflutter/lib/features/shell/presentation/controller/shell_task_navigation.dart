import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/business_providers.dart';
import '../../../../app/conversation_providers.dart';
import '../../../../app/home_notification_providers.dart';
import '../../../conversation/domain/conversation_ids.dart';
import '../../../conversation/presentation/controller/conversation_state.dart';
import '../../../conversation/presentation/pages/conversation_route.dart';
import '../../../conversation/presentation/widgets/task_entry_permission_guard.dart';
import '../../../home/domain/home_config.dart';
import '../../../settings/presentation/widgets/online_entry_guard.dart';
import '../../../tasks/domain/task_records.dart';
import '../../../tasks/presentation/pages/task_detail_route.dart';
import '../../../translation_history/presentation/pages/translation_history_route.dart';
import '../../../dialer/presentation/pages/dialer_route.dart';
import '../../../../app/home_card_preference_providers.dart';
import '../../../../core/design/native_notice.dart';

/// One navigation owner for home, notification, task detail and continuation.
class ShellTaskNavigation {
  ShellTaskNavigation({
    required this.ref,
    required this.context,
    required this.current,
    required this.generation,
    required this.onReturned,
  });
  final WidgetRef ref;
  final BuildContext Function() context;
  final bool Function() current;
  final int Function() generation;
  final VoidCallback onReturned;
  bool _busy = false;
  Future<void> _run(Future<void> Function(bool Function()) action) async {
    if (_busy || !current()) return;
    _busy = true;
    final version = generation(), epoch = ref.read(loginEpochProvider);
    bool valid() =>
        current() &&
        version == generation() &&
        ref.read(loginEpochProvider) == epoch;
    try {
      await action(valid);
    } finally {
      _busy = false;
    }
  }

  Future<void> conversation(
    ConversationEntry entry, {
    String? notificationTaskId,
  }) => _run(
    (valid) =>
        _conversation(entry, valid, notificationTaskId: notificationTaskId),
  );
  Future<void> _conversation(
    ConversationEntry entry,
    bool Function() valid, {
    String? notificationTaskId,
  }) async {
    if (!valid() || !await allowOnlineEntry(context()) || !valid()) return;
    if (!await allowTaskMicrophoneEntry(context(), valid) || !valid()) return;
    final owned = ConversationEntry(
      sessionId: entry.sessionId,
      title: entry.title,
      restore: entry.restore,
      skillId: entry.skillId,
      opening: entry.opening,
      selectedContact: entry.selectedContact,
      ownerEpoch: ref.read(loginEpochProvider),
    );
    await Navigator.of(context()).push<void>(
      MaterialPageRoute(builder: (_) => ConversationRoute(entry: owned)),
    );
    if (!valid()) return;
    final notifications = ref.read(homeNotificationReadStoreProvider) == null
        ? null
        : ref.read(homeNotificationControllerProvider.notifier);
    await notifications?.markTaskRead(
      sessionId: entry.sessionId,
      taskId: notificationTaskId,
    );
    if (!valid()) return;
    await ref.read(taskControllerProvider.notifier).refresh();
    if (valid()) onReturned();
  }

  Future<void> entry(HomeCard card) => _run((valid) async {
    var installedVersion = '';
    if (card.minimumVersion?.isNotEmpty == true) {
      try {
        installedVersion = await ref.read(homeInstalledVersionProvider.future);
      } catch (_) {
        if (valid()) showNativeNotice(context(), '无法读取当前安装版本，请重试。');
        return;
      }
    }
    if (!valid() || !card.canEnter(installedVersion)) return;
    if (card.action == HomeAction.translation) {
      if (!await allowOnlineEntry(context()) || !valid()) return;
      if (!await allowTaskMicrophoneEntry(context(), valid) || !valid()) return;
      await openDialer(context(), translationEntry: true);
      if (valid()) {
        await ref.read(taskControllerProvider.notifier).refresh();
        if (valid()) onReturned();
      }
      return;
    }
    await _conversation(
      ConversationEntry(
        sessionId: newConversationId(),
        title: card.title,
        skillId: card.skillId,
        opening: card.opening,
      ),
      valid,
    );
  });

  Future<void> task(TaskRecord row) => _run((valid) async {
    if (!await allowOnlineEntry(context()) || !valid()) return;
    await ref.read(taskControllerProvider.notifier).markRead(row);
    if (!valid()) return;
    if (row.canRestore && row.sessionId!.trim().isNotEmpty) {
      await _conversation(
        ConversationEntry(
          sessionId: row.sessionId!,
          title: row.title,
          restore: true,
        ),
        valid,
        notificationTaskId: row.taskId,
      );
      return;
    }
    final ownerEpoch = ref.read(loginEpochProvider);
    bool resume = false;
    if (row.kind == TaskRecordKind.translation && row.callId != null) {
      await Navigator.of(context()).push<void>(
        MaterialPageRoute(
          builder: (_) => TranslationHistoryRoute(callId: row.callId!),
        ),
      );
    } else {
      resume =
          await Navigator.of(context()).push<bool>(
            MaterialPageRoute(
              builder: (_) =>
                  TaskDetailRoute(record: row, ownerEpoch: ownerEpoch),
            ),
          ) ==
          true;
    }
    if (!valid()) return;
    final notifications = ref.read(homeNotificationReadStoreProvider) == null
        ? null
        : ref.read(homeNotificationControllerProvider.notifier);
    await notifications?.markTaskRead(
      sessionId: row.sessionId,
      taskId: row.taskId,
      translationCallId: row.kind == TaskRecordKind.translation
          ? row.callId
          : null,
    );
    if (!valid()) return;
    await ref.read(taskControllerProvider.notifier).refresh();
    if (!valid()) return;
    onReturned();
    if (resume) {
      await _conversation(
        ConversationEntry(
          sessionId: row.canRestore ? row.sessionId! : newConversationId(),
          title: row.canRestore ? row.title : '',
          restore: row.canRestore,
        ),
        valid,
        notificationTaskId: row.taskId,
      );
    }
  });
}
