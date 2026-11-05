import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/trusted_caller_home_guide_providers.dart';
import '../../../../app/trusted_caller_providers.dart';
import '../../../../core/design/native_notice.dart';
import '../controller/trusted_caller_home_guide_controller.dart';
import '../pages/trusted_caller_settings_entry.dart';
import 'trusted_caller_home_guide.dart';

enum _GuideStage { hidden, guide, reminder }

/// Only owns the home prompt. SDK pages and authorization remain vendor-owned.
class TrustedCallerHomeGuideHost extends ConsumerStatefulWidget {
  const TrustedCallerHomeGuideHost({
    super.key,
    required this.active,
    required this.child,
  });
  final bool active;
  final Widget child;
  @override
  ConsumerState<TrustedCallerHomeGuideHost> createState() =>
      _HomeGuideHostState();
}

class _HomeGuideHostState extends ConsumerState<TrustedCallerHomeGuideHost>
    with WidgetsBindingObserver {
  TrustedCallerHomeGuideController? _controller;
  Timer? _timer;
  int _generation = 0;
  _GuideStage _stage = _GuideStage.hidden;
  bool _busy = false;
  bool _foreground = true;

  bool get _current =>
      mounted &&
      widget.active &&
      _foreground &&
      ModalRoute.of(context)?.isCurrent == true &&
      _controller != null &&
      ref.read(trustedCallerOwnerProvider)?.matches(_controller!.owner) == true;

  @override
  void initState() {
    super.initState();
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
    ++_generation;
    _stage = _GuideStage.hidden;
    _busy = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    setState(() {
      _foreground = state == AppLifecycleState.resumed;
      if (!_foreground) _cancel();
    });
    if (_foreground) unawaited(_controller?.load());
  }

  void _schedule() {
    if (!_current) {
      _cancel();
      return;
    }
    if (_stage != _GuideStage.hidden ||
        _timer != null ||
        !ref.read(trustedCallerHomeGuideProvider).eligible) {
      return;
    }
    final generation = _generation;
    final controller = _controller!;
    _timer = Timer(const Duration(milliseconds: 300), () {
      _timer = null;
      if (!_current ||
          generation != _generation ||
          !ref.read(trustedCallerHomeGuideProvider).eligible) {
        return;
      }
      setState(() => _stage = _GuideStage.guide);
      // Persist when shown, not when authorized. Failures remain visible as errors.
      unawaited(_recordShown(controller, generation));
    });
  }

  Future<void> _recordShown(
    TrustedCallerHomeGuideController controller,
    int generation,
  ) async {
    final saved = await controller.record();
    if (mounted && !saved && _current && generation == _generation) {
      showNativeNotice(context, ref.read(trustedCallerHomeGuideProvider).error);
    }
  }

  Future<void> _act(
    TrustedCallerHomeGuideAction action,
    VoidCallback open,
  ) async {
    if (!_current || _busy || _stage != _GuideStage.guide) return;
    if (action == TrustedCallerHomeGuideAction.dismiss) {
      setState(() => _stage = _GuideStage.reminder);
      return;
    }
    if (action == TrustedCallerHomeGuideAction.authorize) {
      setState(() => _stage = _GuideStage.hidden);
      open();
      return;
    }
    final generation = _generation;
    setState(() => _busy = true);
    final saved = await _controller!.record(disabled: true);
    if (!mounted || !_current || generation != _generation) return;
    setState(() {
      _busy = false;
      if (saved) _stage = _GuideStage.hidden;
    });
    if (!saved) {
      showNativeNotice(context, ref.read(trustedCallerHomeGuideProvider).error);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return widget.child;
    }
    ref.watch(trustedCallerOwnerProvider);
    ref.watch(trustedCallerHomeGuideProvider);
    final controller = ref.read(trustedCallerHomeGuideProvider.notifier);
    if (!identical(_controller, controller)) {
      _cancel();
      _controller = controller;
    }
    _schedule();
    final visible = _stage != _GuideStage.hidden && _current;
    return TrustedCallerSettingsEntry(
      builder: (context, open) => PopScope(
        canPop: !visible,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop || !visible) return;
          if (_stage == _GuideStage.guide) {
            _act(TrustedCallerHomeGuideAction.dismiss, open);
          } else if (!_busy) {
            setState(() => _stage = _GuideStage.hidden);
          }
        },
        child: Stack(
          children: [
            IgnorePointer(
              ignoring: visible,
              child: ExcludeFocus(
                excluding: visible,
                child: ExcludeSemantics(
                  excluding: visible,
                  child: widget.child,
                ),
              ),
            ),
            if (visible) ...[
              Positioned.fill(
                child: ModalBarrier(
                  key: const Key('trusted-home-barrier'),
                  color: _stage == _GuideStage.guide
                      ? const Color(0x73000000)
                      : const Color(0x2E0F0F12),
                  dismissible: _stage == _GuideStage.guide && !_busy,
                  onDismiss: () =>
                      _act(TrustedCallerHomeGuideAction.dismiss, open),
                ),
              ),
              Positioned.fill(
                child: AbsorbPointer(
                  absorbing: _busy,
                  child: _stage == _GuideStage.guide
                      ? TrustedCallerHomeGuide(
                          onAction: (action) => _act(action, open),
                        )
                      : TrustedCallerHomeReminder(
                          onConfirm: () =>
                              setState(() => _stage = _GuideStage.hidden),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
