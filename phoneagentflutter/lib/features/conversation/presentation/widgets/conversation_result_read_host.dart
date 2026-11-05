import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../core/diagnostics/diagnostic_event.dart';
import '../../../tasks/domain/visible_task_result_read.dart';
import '../../../tasks/domain/task_page.dart';
import '../../domain/conversation_messages.dart';

TaskResultReadDiagnostic taskResultReadDiagnostics(DiagnosticSink sink) =>
    (sessionId, stage, outcome) {
      final result = switch (stage) {
        'ack_started' => DiagnosticResult.started,
        'ack_succeeded' => DiagnosticResult.succeeded,
        'ack_failed' => DiagnosticResult.failed,
        _ => null,
      };
      if (result == null) return;
      emitDiagnostic(
        sink,
        DiagnosticEvent(
          operation: DiagnosticOperation.taskResultRead,
          result: result,
          sessionId: sessionId,
          failureKind: result != DiagnosticResult.failed
              ? null
              : switch (outcome) {
                  'timeout' => DiagnosticFailureKind.timeout,
                  'state' => DiagnosticFailureKind.state,
                  _ => DiagnosticFailureKind.other,
                },
        ),
      );
    };

class ConversationResultReadHost extends StatefulWidget {
  const ConversationResultReadHost({
    super.key,
    required this.sessionId,
    required this.messages,
    required this.isCurrent,
    required this.markRead,
    required this.child,
    this.diagnostic,
  });
  final String sessionId;
  final List<ConversationMessage> messages;
  final bool Function() isCurrent;
  final Future<void> Function(TaskRef)? markRead;
  final TaskResultReadDiagnostic? diagnostic;
  final Widget child;
  @override
  State<ConversationResultReadHost> createState() => _ReadHostState();
}

class _ReadHostState extends State<ConversationResultReadHost>
    with WidgetsBindingObserver {
  late final VisibleTaskResultRead? _read;
  bool _scheduled = false, _lastVisible = false;
  @override
  void initState() {
    super.initState();
    _read = widget.markRead == null
        ? null
        : VisibleTaskResultRead(
            widget.sessionId,
            widget.markRead!,
            () => mounted && _visible,
            diagnostic: widget.diagnostic,
          );
    WidgetsBinding.instance.addObserver(this);
  }

  bool get _visible =>
      mounted &&
      widget.isCurrent() &&
      ModalRoute.of(context)?.isCurrent == true &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);
  void _schedule() {
    if (_scheduled || _read == null) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) {
        final visible = _visible;
        _lastVisible = visible;
        _read.show(widget.messages, visible: visible);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _schedule();
      WidgetsBinding.instance.ensureVisualUpdate();
    } else {
      _lastVisible = false;
      _read?.show(widget.messages, visible: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ModalRoute.of(
      context,
    ); // Re-evaluate when a covering route opens or closes.
    _lastVisible = _visible;
    _schedule();
    return widget.child;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final read = _read;
    if (read != null) unawaited(read.close(widget.messages, _lastVisible));
    super.dispose();
  }
}
