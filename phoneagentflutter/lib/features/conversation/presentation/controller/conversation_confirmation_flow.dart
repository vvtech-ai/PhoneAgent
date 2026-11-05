import 'dart:async';
import '../../../calls/domain/call_launch_coordinator.dart';
import '../../../calls/presentation/controller/conversation_call_controller.dart';
import '../../domain/confirmation/call_confirmation_policy.dart';
import '../../domain/confirmation/call_confirmation_reply.dart';
import '../../domain/confirmation/call_confirmation_reply_coordinator.dart';
import '../../domain/confirmation/confirmation_supplement.dart';
import '../../domain/confirmation/confirmation_supplement_outbox.dart';

/// Confirmation interaction only; the existing call coordinator owns execution.
class ConversationConfirmationFlow {
  ConversationConfirmationFlow({
    required this.accountId,
    required this.sessionId,
    required this.calls,
    required this.generation,
    required this.current,
    required this.nextId,
    required this.showSupplement,
    required this.notice,
    required this.changed,
    this.supplements,
    CallConfirmationReplyRepository? repository,
  }) {
    if (repository != null) {
      _replies = CallConfirmationReplyCoordinator(
        repository: repository,
        currentScope: _scope,
      );
    }
  }
  final String accountId, sessionId;
  final ConversationCallController? Function() calls;
  final int Function() generation;
  final bool Function() current;
  final String Function() nextId;
  final void Function(ConfirmationSupplement) showSupplement;
  final void Function(String) notice;
  final void Function() changed;
  final ConfirmationSupplementOutbox? supplements;
  CallConfirmationReplyCoordinator? _replies;
  String? get pendingText => _replies?.pendingText;
  static const _reprompt = '请确认是否按当前任务拨打；如需修改，请说明。';

  CallReplyScope? _scope() {
    final call = calls(), launch = call?.snapshot.launch;
    final request = launch?.request;
    if (!current() ||
        call?.snapshot.showCall == true ||
        request == null ||
        !{
          CallLaunchPhase.awaitingConfirmation,
          CallLaunchPhase.restored,
          CallLaunchPhase.blocked,
          CallLaunchPhase.failed,
        }.contains(launch!.phase)) {
      return null;
    }
    final card = request.confirmation.rows
        .map((r) => '${r.label}：${r.value}')
        .join('\n');
    return (
      accountId: accountId,
      sessionId: sessionId,
      toolId: request.toolId,
      specSignature: request.specSignature,
      generation: generation(),
      cardText: card,
    );
  }

  /// null means a normal Agent turn; true/false reflects accepted/coalesced input.
  bool? handle(String text, bool Function() continueConversation) {
    final call = calls();
    if (call == null) return null;
    if ({
          CallLaunchPhase.waiting,
          CallLaunchPhase.checking,
          CallLaunchPhase.submitting,
          CallLaunchPhase.submitted,
          CallLaunchPhase.uncertain,
        }.contains(call.snapshot.launch.phase) &&
        text.trim() == call.confirmationText.trim()) {
      return false;
    }
    call.pausePreparation();
    final scope = _scope();
    if (scope == null) return null;
    if (!call.cardPresented) {
      notice('请先查看当前任务确认信息，再确认拨打。');
      return false;
    }
    final replies = _replies;
    if (replies == null) {
      _supplement(scope, text, _reprompt);
      return true;
    }
    return replies.submit(text, scope, (user, reply) {
      _apply(scope, user, reply, continueConversation);
      if (current()) changed();
    });
  }

  void _apply(
    CallReplyScope scope,
    String user,
    CallReply reply,
    bool Function() continueConversation,
  ) {
    if (_scope() != scope || calls()?.cardPresented != true) return;
    if (reply.unavailable) {
      notice('暂时无法识别确认，请重试；当前未拨打。');
      return;
    }
    switch (reply.decision) {
      case CallReplyDecision.confirm:
        calls()?.confirm(user);
      case CallReplyDecision.edit:
        continueConversation();
      case CallReplyDecision.cancel:
      case CallReplyDecision.newRequest:
        continueConversation();
      case CallReplyDecision.question:
        _supplement(
          scope,
          user,
          reply.answer.isEmpty ? _reprompt : '${reply.answer}\n$_reprompt',
        );
      case CallReplyDecision.wait:
        _supplement(scope, user, '好的，暂不拨打。准备好后请确认当前任务。');
      case CallReplyDecision.unclear:
        _supplement(scope, user, _reprompt);
    }
  }

  void _supplement(CallReplyScope scope, String user, String answer) {
    if (!current()) return;
    final record = ConfirmationSupplement(
      id: nextId(),
      toolId: scope.toolId,
      userText: user,
      assistantText: answer,
    );
    showSupplement(record);
    if (supplements != null) {
      unawaited(supplements!.add(record));
    } else {
      notice('补充记录保存能力尚未接入；当前未拨打。');
    }
  }

  void invalidate() => _replies?.invalidate();
  void close() {
    invalidate();
    supplements?.close();
  }
}
