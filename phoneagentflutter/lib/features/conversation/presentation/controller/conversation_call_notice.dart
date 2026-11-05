import '../../../../core/identifiers/content_hash.dart';
import '../../../calls/domain/call_admission.dart';
import '../../../calls/domain/call_launch_coordinator.dart';
import '../../domain/conversation_messages.dart';

abstract final class ConversationCallNotice {
  static ConversationMessage? message(CallLaunchState launch) {
    if (launch.decision?.kind != CallAdmissionKind.firstInsufficient) {
      return null;
    }
    final request = launch.request!;
    return ConversationMessage(
      id: 'local:points:${request.identity}',
      role: MessageRole.assistant,
      text: launch.decision!.firstNotice,
      commandId: 'task-call-points-notice:${contentHash(request.stableAlias)}',
      transient: true,
    );
  }

  static String warning(CallLaunchState launch) =>
      launch.phase == CallLaunchPhase.failed
      ? '无法确认当前登录或积分状态，请同步后重试。'
      : launch.noticeSaveFailed
      ? '积分不足提示暂未同步，后续以历史记录为准。'
      : '';
}
