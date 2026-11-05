import 'dart:async';
import 'call_confirmation_policy.dart';
import 'call_confirmation_reply.dart';

/// Binds classification to the exact visible card and current account/run.
class CallConfirmationReplyCoordinator {
  CallConfirmationReplyCoordinator({
    required this.repository,
    required this.currentScope,
    this.timeout = const Duration(seconds: 12),
  });
  final CallConfirmationReplyRepository repository;
  final CallReplyScope? Function() currentScope;
  final Duration timeout;
  int _revision = 0;
  CallReplyScope? _inFlight;
  String? _text;
  String? get pendingText => _text;

  void invalidate() {
    _revision++;
    _inFlight = null;
    _text = null;
  }

  bool submit(
    String text,
    CallReplyScope scope,
    void Function(String, CallReply) apply,
  ) {
    if (_inFlight == scope && _text == text) return false;
    final revision = ++_revision;
    _inFlight = scope;
    _text = text;
    unawaited(_resolve(text, scope, revision, apply));
    return true;
  }

  Future<void> _resolve(
    String text,
    CallReplyScope scope,
    int revision,
    void Function(String, CallReply) apply,
  ) async {
    CallReply reply;
    try {
      reply = await repository.classify(scope, text).timeout(timeout);
    } catch (_) {
      reply = const CallReply(CallReplyDecision.unclear, '', true);
    }
    if (_revision != revision) return;
    _inFlight = null;
    _text = null;
    if (currentScope() != scope) return;
    apply(text, reply);
  }
}
