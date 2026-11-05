import 'package:flutter/foundation.dart';
import 'task_operation_feedback.dart';

enum TaskOperationTraceStage {
  operationStarted,
  guardRejected,
  actionCompleted,
  actionFailed,
  operationInvalidated,
  feedbackEmitted,
  hostReceived,
  hostSuppressed,
  noticeRequested,
}

/// USB field diagnostics accept only fixed enums and boolean state, never data.
void traceTaskOperation(
  TaskOperationTraceStage stage,
  TaskOperation? operation, {
  required bool mounted,
  bool? active,
  bool? visiblePage,
  bool? epochCurrent,
  bool? paged,
  bool? busy,
  bool? succeeded,
}) {
  if (operation == null) return;
  try {
    debugPrint(
      'TaskFeedbackTrace stage=${stage.name} operation=${operation.name} '
      'mounted=$mounted'
      '${active == null ? '' : ' active=$active'}'
      '${visiblePage == null ? '' : ' visiblePage=$visiblePage'}'
      '${epochCurrent == null ? '' : ' epochCurrent=$epochCurrent'}'
      '${paged == null ? '' : ' paged=$paged'}'
      '${busy == null ? '' : ' busy=$busy'}'
      '${succeeded == null ? '' : ' succeeded=$succeeded'}',
    );
  } catch (_) {
    // A diagnostic sink must never change task or notification behavior.
  }
}
