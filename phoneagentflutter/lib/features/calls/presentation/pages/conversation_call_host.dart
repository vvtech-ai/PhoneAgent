import '../../../../core/design/native_business_dialog.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../../domain/call_admission.dart';
import '../../domain/call_launch_coordinator.dart';
import '../controller/conversation_call_controller.dart';
import '../controller/call_presentation.dart';
import '../controller/call_monitor_controller.dart';
import '../widgets/call_outcome_scope.dart';
import '../widgets/call_controls.dart';
import 'call_session_page.dart';

/// Keeps the conversation mounted while the single-call surface is visible.
class ConversationCallHost extends StatefulWidget {
  const ConversationCallHost({
    super.key,
    required this.controller,
    required this.modelName,
    required this.child,
    this.createMonitor,
  });
  final ConversationCallController? controller;
  final String modelName;
  final Widget child;
  final CallMonitorController Function()? createMonitor;
  @override
  State<ConversationCallHost> createState() => _ConversationCallHostState();
}

class _ConversationCallHostState extends State<ConversationCallHost>
    with WidgetsBindingObserver {
  void Function()? _remove;
  void Function()? _removeMonitor;
  CallMonitorController? _monitor;
  final Set<String> _dialogs = {};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenMonitor();
    _listen();
  }

  void _listenMonitor() {
    _monitor = widget.createMonitor?.call();
    _removeMonitor = _monitor?.addListener((_) {
      if (mounted) setState(() {});
    }, fireImmediately: false);
    _syncMonitor();
  }

  void _syncMonitor() {
    final call = widget.controller?.snapshot;
    _monitor?.bind(
      call?.call?.target,
      connected: call?.call?.connected == true,
      active:
          call?.showCall == true &&
          call?.call != null &&
          CallPresentation.active(call!.call!),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_monitor?.stop());
  }

  @override
  void didUpdateWidget(covariant ConversationCallHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.createMonitor != widget.createMonitor) {
      _removeMonitor?.call();
      _monitor?.dispose();
      _listenMonitor();
    }
    if (oldWidget.controller != widget.controller) {
      _remove?.call();
      _dialogs.clear();
      _listen();
    }
    _syncMonitor();
  }

  void _listen() {
    _remove = widget.controller?.addListener((value) {
      if (!mounted) return;
      _syncMonitor();
      setState(() {});
      final launch = value.launch;
      if (launch.phase == CallLaunchPhase.blocked &&
          launch.decision?.kind == CallAdmissionKind.repeatedInsufficient &&
          _dialogs.add(launch.request!.identity)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted ||
              widget.controller?.snapshot.launch.request != launch.request) {
            return;
          }
          showDialog<void>(
            context: context,
            builder: (context) => NativeBusinessDialog(
              title: launch.decision!.title,
              message: launch.decision!.message,
              showDismiss: false,
              confirmLabel: '知道了',
              onConfirm: () => Navigator.pop(context),
            ),
          ).whenComplete(() => _dialogs.remove(launch.request!.identity));
        });
      }
    }, fireImmediately: false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _remove?.call();
    _removeMonitor?.call();
    _monitor?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller?.snapshot;
    final show = state?.showCall == true && state?.call != null;
    return PopScope(
      canPop: !show,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: show,
            child: TickerMode(
              enabled: !show,
              child: ExcludeFocus(
                excluding: show,
                child: CallOutcomeScope(
                  awaiting: widget.controller?.awaitingOutcome == true,
                  preview: state?.call?.progress.preview,
                  callAttemptId: state?.call?.target.attemptId ?? '',
                  callId: state?.call?.target.callId ?? '',
                  child: widget.child,
                ),
              ),
            ),
          ),
          if (show)
            CallSessionPage(
              state: state!.call!,
              monitor: _monitor?.snapshot ?? const CallMonitorView(),
              modelName: widget.modelName,
              seconds: state.seconds,
              targetName:
                  widget.controller?.activeRequest?.confirmation.targetName ??
                  '',
              phoneNumber:
                  widget.controller?.activeRequest?.confirmation.phoneNumber ??
                  '',
              onHangup: () async {
                await _monitor?.stop();
                if (mounted) await widget.controller?.hangUp();
              },
              onMonitor: () => _monitor?.toggle(),
              onSource: () async {
                final monitor = _monitor;
                if (monitor == null || monitor.snapshot.controlsBusy) {
                  return;
                }
                final source = await showCallAudioSources(
                  context,
                  monitor.snapshot,
                );
                if (mounted && source != null && identical(monitor, _monitor)) {
                  await monitor.select(source);
                }
              },
            ),
        ],
      ),
    );
  }
}
