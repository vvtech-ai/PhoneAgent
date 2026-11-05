import '../../../../core/design/native_notice.dart';
import '../../domain/translation_call_failure.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/translation_call_view.dart';
import '../controller/translation_call_controller.dart';
import '../widgets/translation_call_controls.dart';
import 'translation_call_page.dart';

/// Owns the shared controller lifetime; callers inject external dependencies.
class TranslationSessionRoute extends StatefulWidget {
  const TranslationSessionRoute({
    super.key,
    required this.createController,
    required this.target,
    this.headerBuilder,
  });
  final TranslationCallController Function() createController;
  final String target;
  final Widget Function(BuildContext, TranslationCallController)? headerBuilder;
  @override
  State<TranslationSessionRoute> createState() =>
      _TranslationSessionRouteState();
}

class _TranslationSessionRouteState extends State<TranslationSessionRoute> {
  late final TranslationCallController _controller;
  late final VoidCallback _removeListener;
  bool _closing = false;
  String _lastError = '';
  @override
  void initState() {
    super.initState();
    _controller = widget.createController();
    _removeListener = _controller.addListener((state) {
      if (!mounted) return;
      setState(() {});
      if (!state.terminal && !state.stopping && state.error != _lastError) {
        _lastError = state.error;
        if (state.error.isNotEmpty) _notice(state.error);
      }
      if (state.terminal && !_closing) {
        _closing = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            if (state.phase == TranslationPhase.failed) {
              showNativeNotice(
                context,
                state.error.isEmpty
                    ? translationCallFailureMessage('UNKNOWN')
                    : state.error,
                overlay: Overlay.of(context, rootOverlay: true),
                duration: const Duration(seconds: 3),
              );
            }
            if (state.settlementNotice.isNotEmpty) {
              showNativeNotice(
                context,
                state.settlementNotice,
                overlay: Overlay.of(context, rootOverlay: true),
              );
            }
            Navigator.pop(context);
          }
        });
      }
    }, fireImmediately: false);
    unawaited(_controller.start());
  }

  void _notice(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showNativeNotice(context, message);
    });
  }

  void _control(Future<void> Function() action) {
    unawaited(
      Future<void>.sync(action).catchError((Object _) {
        if (mounted) _notice('操作未成功，原状态未改变，请重试');
      }),
    );
  }

  @override
  void dispose() {
    _removeListener();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.snapshot;
    return PopScope(
      canPop: state.terminal,
      child: TranslationCallPage(
        state: state,
        target: widget.target,
        previewHeader: widget.headerBuilder?.call(context, _controller),
        controls: TranslationCallControls(
          state: state,
          onMute: () => _control(_controller.mute),
          onSpeaker: () => _control(_controller.speaker),
          onPad: _controller.dialPad,
          onDigit: (digit) => _control(() => _controller.digit(digit)),
          onHangup: () => _control(_controller.hangup),
        ),
      ),
    );
  }
}
