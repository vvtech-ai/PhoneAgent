/// Fixed vocabulary for correlating a batch progress read with its visible result.
enum DiagnosticBatchResultStage {
  progressFetch,
  progressRead,
  historyRead,
  visibleResult,
  narrationWaiting,
  narrationTerminalSignal,
  narrationBlocked,
  narrationHandoff,
}

enum DiagnosticBatchExecution { pending, finished, executionError, unknown }

enum DiagnosticBatchResultReason {
  controllerClosed,
  resultEligibilityLost,
  userStoppedSpeech,
  explicitInterruption,
  playbackFailed,
  speechDisabled,
  resultNotReady,
  audioActive,
  enqueueFailed,
}

class DiagnosticBatchResultDetails {
  const DiagnosticBatchResultDetails({
    required this.stage,
    required this.batchId,
    required this.hasResult,
    this.resultSequence = 0,
    this.execution = DiagnosticBatchExecution.unknown,
    this.completedCount = 0,
    this.totalCount = 0,
    this.pageWaiting,
    this.reason,
  });

  final DiagnosticBatchResultStage stage;
  final String batchId;
  final bool hasResult;
  final int resultSequence, completedCount, totalCount;
  final DiagnosticBatchExecution execution;
  final bool? pageWaiting;
  final DiagnosticBatchResultReason? reason;

  static DiagnosticBatchExecution executionFromWire(Object? value) =>
      switch (value) {
        'PENDING' => DiagnosticBatchExecution.pending,
        'FINISHED' => DiagnosticBatchExecution.finished,
        'EXECUTION_ERROR' => DiagnosticBatchExecution.executionError,
        _ => DiagnosticBatchExecution.unknown,
      };

  Map<String, Object> toJson() => {
    'stage': stage.name,
    if (RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(batchId)) 'batchId': batchId,
    'hasResult': hasResult,
    'resultSequence': resultSequence.clamp(0, 9007199254740991),
    'execution': execution.name,
    'completedCount': completedCount.clamp(0, 10000),
    'totalCount': totalCount.clamp(0, 10000),
    if (pageWaiting != null) 'pageWaiting': pageWaiting!,
    if (reason != null) 'reason': reason!.name,
  };

  factory DiagnosticBatchResultDetails.fromJson(Map<String, dynamic> json) =>
      DiagnosticBatchResultDetails(
        stage: DiagnosticBatchResultStage.values.firstWhere(
          (value) => value.name == json['stage'],
          orElse: () => DiagnosticBatchResultStage.historyRead,
        ),
        batchId: json['batchId'] is String ? json['batchId'] as String : '',
        hasResult: json['hasResult'] == true,
        resultSequence: json['resultSequence'] is int
            ? json['resultSequence'] as int
            : 0,
        execution: DiagnosticBatchExecution.values.firstWhere(
          (value) => value.name == json['execution'],
          orElse: () => DiagnosticBatchExecution.unknown,
        ),
        completedCount: json['completedCount'] is int
            ? json['completedCount'] as int
            : 0,
        totalCount: json['totalCount'] is int ? json['totalCount'] as int : 0,
        pageWaiting: json['pageWaiting'] is bool
            ? json['pageWaiting'] as bool
            : null,
        reason: DiagnosticBatchResultReason.values
            .where((value) => value.name == json['reason'])
            .firstOrNull,
      );
}
