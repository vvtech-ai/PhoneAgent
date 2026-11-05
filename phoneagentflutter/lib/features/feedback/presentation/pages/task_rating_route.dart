import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/task_rating_providers.dart';
import '../../domain/call_evaluation.dart';
import '../controller/task_rating_controller.dart';
import '../widgets/task_rating_sheet.dart';
import '../widgets/native_task_rating_entry.dart';
import '../widgets/native_task_rating_success.dart';

class TaskRatingRoute extends ConsumerStatefulWidget {
  const TaskRatingRoute({super.key, required this.target, this.resultRevision});
  final FeedbackTarget target;
  final String? resultRevision;
  @override
  ConsumerState<TaskRatingRoute> createState() => _TaskRatingRouteState();
}

class _TaskRatingRouteState extends ConsumerState<TaskRatingRoute> {
  final Object _owner = Object();
  TaskRatingController? _controller;
  bool _claimScheduled = false, _opening = false;
  @override
  void didUpdateWidget(covariant TaskRatingRoute oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target ||
        oldWidget.resultRevision == widget.resultRevision) {
      return;
    }
    final controller = _controller;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(_controller, controller)) controller?.refresh();
    });
  }

  @override
  void dispose() {
    final controller = _controller;
    Future.microtask(() => controller?.release(_owner));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = taskRatingControllerProvider(widget.target);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    if (_controller != controller) {
      final old = _controller;
      Future.microtask(() => old?.release(_owner));
      _controller = controller;
    }
    if (state.owner == null && !_claimScheduled) {
      _claimScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _claimScheduled = false;
        if (mounted && identical(_controller, controller)) {
          controller.claim(_owner);
        }
      });
    }
    if (!state.visible || !identical(state.owner, _owner)) {
      return const SizedBox.shrink();
    }
    return NativeTaskRatingEntry(
      readOnly: state.readOnly,
      rewardHint: state.rewardHint,
      grantedPoints: state.eligibility?.grantedPoints,
      onOpen: () => _open(controller),
    );
  }

  Future<void> _open(TaskRatingController controller) async {
    if (_opening ||
        !mounted ||
        !controller.mounted ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _opening = true;
    controller.open();
    final container = ProviderScope.containerOf(context);
    final target = widget.target;
    var sheetFinished = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      barrierColor: const Color(0x66000000),
      enableDrag: false,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (sheetContext) => UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) {
            final state = ref.watch(taskRatingControllerProvider(target));
            void close() {
              if (sheetFinished ||
                  !sheetContext.mounted ||
                  !controller.mounted ||
                  ModalRoute.of(sheetContext)?.isCurrent != true ||
                  ref.read(taskRatingControllerProvider(target)).saving) {
                return;
              }
              sheetFinished = true;
              controller.close();
              Navigator.of(sheetContext).pop();
            }

            return PopScope(
              canPop: !state.saving,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: SizedBox(
                  height:
                      (MediaQuery.sizeOf(context).height * .94 -
                              MediaQuery.viewInsetsOf(context).bottom)
                          .clamp(0.0, double.infinity),
                  child: TaskRatingSheet(
                    state: state,
                    onClose: close,
                    onRate: controller.rate,
                    onSkipClone: controller.skipClone,
                    onSuggestion: controller.suggestion,
                    onRetryDraft: controller.retryDraft,
                    onSubmit: () async {
                      if (sheetFinished ||
                          !sheetContext.mounted ||
                          !controller.mounted ||
                          ModalRoute.of(sheetContext)?.isCurrent != true) {
                        return;
                      }
                      await controller.submit();
                      if (sheetFinished ||
                          !sheetContext.mounted ||
                          !controller.mounted ||
                          ModalRoute.of(sheetContext)?.isCurrent != true ||
                          !controller.submittedSuccessfully) {
                        return;
                      }
                      sheetFinished = true;
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    _opening = false;
    if (!mounted || !controller.mounted) return;
    controller.close();
    if (!controller.submittedSuccessfully) return;
    final points = controller.grantedPoints;
    var successFinished = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0x66000000),
      builder: (dialogContext) => NativeTaskRatingSuccess(
        grantedPoints: points,
        onDismiss: () {
          if (successFinished ||
              !dialogContext.mounted ||
              ModalRoute.of(dialogContext)?.isCurrent != true) {
            return;
          }
          successFinished = true;
          Navigator.of(dialogContext).pop();
        },
      ),
    );
    if (controller.mounted) controller.dismissSuccess();
  }
}
