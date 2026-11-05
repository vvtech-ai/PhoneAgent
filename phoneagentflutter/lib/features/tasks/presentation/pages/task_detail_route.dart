import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/business_providers.dart';
import '../../../../app/task_detail_providers.dart';
import '../../../../app/task_artifact_providers.dart';
import '../../../conversation/presentation/widgets/receipts/conversation_recording_host.dart';
import '../../../feedback/presentation/pages/call_evaluation_route.dart';
import '../../domain/task_records.dart';
import 'task_detail_page.dart';

class TaskDetailRoute extends ConsumerStatefulWidget {
  const TaskDetailRoute({super.key, required this.record, this.ownerEpoch});
  final TaskRecord record;
  final int? ownerEpoch;
  @override
  ConsumerState<TaskDetailRoute> createState() => _TaskDetailRouteState();
}

class _TaskDetailRouteState extends ConsumerState<TaskDetailRoute> {
  late final int? _epoch;
  bool _leaving = false;
  @override
  void initState() {
    super.initState();
    _epoch = widget.ownerEpoch ?? ref.read(loginEpochProvider);
  }

  void _leave([bool restore = false]) {
    if (_leaving || !mounted || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _leaving = true;
    Navigator.of(context).pop(restore);
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(loginEpochProvider) != _epoch) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _leave());
      return const Scaffold(body: Center(child: Text('账号已切换')));
    }
    final request = (record: widget.record, epoch: _epoch);
    final state = ref.watch(taskDetailControllerProvider(request));
    final controller = ref.read(taskDetailControllerProvider(request).notifier);
    if (state.messages.any((message) => message.artifact != null)) {
      ref.watch(taskArtifactDownloadProvider(controller).notifier);
    }
    return ConversationRecordingHost(
      voiceMode: false,
      builder: (recording) => TaskDetailPage(
        artifactOwner: controller,
        state: state,
        onClose: _leave,
        onRetry: controller.load,
        recordingBuilder: recording,
        receiptFeedbackBuilder: CallEvaluationRoute.forReceipt,
        onRestore: () => _leave(true),
      ),
    );
  }
}
