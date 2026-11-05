import 'package:flutter/widgets.dart';
import '../../domain/call_progress.dart';

/// Ephemeral presentation of the existing live call owner, never history.
class CallOutcomeScope extends InheritedWidget {
  const CallOutcomeScope({
    super.key,
    required this.awaiting,
    this.preview,
    this.callAttemptId = '',
    this.callId = '',
    required super.child,
  });
  final bool awaiting;
  final CallOutcomePreview? preview;
  final String callAttemptId, callId;
  static CallOutcomePreview? previewOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CallOutcomeScope>()?.preview;

  static bool awaitingOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<CallOutcomeScope>()
          ?.awaiting ??
      false;

  static bool awaitingFor(
    BuildContext context, {
    required String callAttemptId,
    required String callId,
  }) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<CallOutcomeScope>();
    if (scope?.awaiting != true) return false;
    final ownerAttempt = scope!.callAttemptId.trim();
    final receiptAttempt = callAttemptId.trim();
    if (ownerAttempt.isNotEmpty && receiptAttempt.isNotEmpty) {
      return ownerAttempt == receiptAttempt;
    }
    final ownerCall = scope.callId.trim();
    return ownerCall.isNotEmpty && ownerCall == callId.trim();
  }

  @override
  bool updateShouldNotify(CallOutcomeScope oldWidget) =>
      awaiting != oldWidget.awaiting ||
      preview != oldWidget.preview ||
      callAttemptId != oldWidget.callAttemptId ||
      callId != oldWidget.callId;
}
