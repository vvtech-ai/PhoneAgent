import 'call_launch_request.dart';

enum CallAdmissionKind { allow, firstInsufficient, repeatedInsufficient }

class CallAdmissionDecision {
  const CallAdmissionDecision(
    this.kind, {
    this.balance,
    this.requiredPoints = 0,
    this.recipientCount = 1,
    this.persistenceFailed = false,
  });
  final CallAdmissionKind kind;
  final int? balance;
  final int requiredPoints, recipientCount;
  final bool persistenceFailed;
  String get title => recipientCount > 1 ? '多路积分不足' : '积分不足';
  String get message => recipientCount > 1
      ? '当前积分不足以呼叫全部联系人。请减少联系人或补充积分后再试。'
      : '当前积分不足以发起本次通话。请补充积分后再试。';
  String get firstNotice =>
      recipientCount > 1 ? '$title，$message' : '积分不足，无法发起本次通话。请补充积分后再试。';
}

abstract final class CallAdmissionPolicy {
  static int firstMinutePoints(String? model) {
    final title = (model ?? '').trim().toUpperCase();
    if (title.contains('3.0') ||
        title.contains('3_0') ||
        title.contains('V3')) {
      return 150;
    }
    if (title.contains('DOUBAO') || title.contains('SEEDUPLEX')) return 110;
    return 100;
  }

  static CallAdmissionDecision evaluate({
    required int? balance,
    required String? model,
    required int recipients,
    required bool notified,
    bool persistenceFailed = false,
  }) {
    final count = recipients < 1 ? 1 : recipients;
    final required = firstMinutePoints(model) * count;
    return CallAdmissionDecision(
      balance == null || balance >= required
          ? CallAdmissionKind.allow
          : notified
          ? CallAdmissionKind.repeatedInsufficient
          : CallAdmissionKind.firstInsufficient,
      balance: balance,
      requiredPoints: required,
      recipientCount: count,
      persistenceFailed: persistenceFailed,
    );
  }
}

abstract interface class CallAdmissionNoticeStore {
  Future<bool> wasNotified(String sessionId, Iterable<String> aliases);
  Future<void> markNotified(String sessionId, Iterable<String> aliases);
}

class CallAdmissionNoticeReceipt {
  const CallAdmissionNoticeReceipt({
    required this.sessionId,
    required this.eventId,
    required this.sequence,
    required this.created,
  });
  final String sessionId, eventId;
  final int sequence;
  final bool created;
}

abstract interface class CallAdmissionNoticeRepository {
  /// Idempotent notice only. Never confirms a call or changes account balance.
  Future<CallAdmissionNoticeReceipt> commit(CallLaunchRequest request);
}

/// Only the idempotent notice may retry transient transport/server failures.
enum CallAdmissionNoticeFailure { retryable, terminal }
