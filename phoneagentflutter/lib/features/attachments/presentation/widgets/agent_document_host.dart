import 'package:flutter/material.dart';
import 'native_agent_document_sheet.dart';
import '../controller/agent_document_controller.dart';

/// Same shared overlay on Web, Android and iOS; only picker IO is platform-bound.
class AgentDocumentHost extends StatefulWidget {
  const AgentDocumentHost({
    super.key,
    required this.controller,
    required this.child,
  });
  final AgentDocumentController? controller;
  final Widget child;
  @override
  State<AgentDocumentHost> createState() => _AgentDocumentHostState();
}

class _AgentDocumentHostState extends State<AgentDocumentHost> {
  void Function()? _remove;
  final _portal = OverlayPortalController();
  @override
  void initState() {
    super.initState();
    _portal.show();
    _listen();
  }

  void _listen() {
    _remove = widget.controller?.addListener((_) {
      if (mounted) setState(() {});
    }, fireImmediately: false);
  }

  @override
  void didUpdateWidget(AgentDocumentHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _remove?.call();
      _listen();
    }
  }

  @override
  void dispose() {
    _remove?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final owner = widget.controller;
    final state = owner?.snapshot;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    bool current() =>
        owner != null &&
        identical(widget.controller, owner) &&
        owner.mounted &&
        state != null &&
        identical(owner.snapshot?.request, state.request);
    void cancel() {
      if (current()) owner!.cancel();
    }

    void choose() {
      if (current()) owner!.choose();
    }

    return PopScope(
      canPop: state == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) cancel();
      },
      child: OverlayPortal.targetsRootOverlay(
        controller: _portal,
        child: ExcludeFocus(excluding: state != null, child: widget.child),
        overlayChildBuilder: (context) {
          final view = View.of(context);
          final padding = EdgeInsets.fromViewPadding(
            view.viewPadding,
            view.devicePixelRatio,
          );
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              viewInsets: EdgeInsets.zero,
              padding: padding,
              viewPadding: padding,
            ),
            child: Positioned.fill(
              child: AnimatedSwitcher(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 280),
                reverseDuration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 280),
                switchInCurve: Curves.easeInOut,
                switchOutCurve: Curves.easeInOut,
                transitionBuilder: (child, animation) {
                  if (child.key == const ValueKey('agent-document-hidden')) {
                    return child;
                  }
                  return AnimatedBuilder(
                    animation: animation,
                    builder: (context, _) {
                      final exiting =
                          animation.status == AnimationStatus.reverse;
                      return IgnorePointer(
                        ignoring: exiting,
                        child: ExcludeFocus(
                          excluding: exiting,
                          child: ExcludeSemantics(
                            excluding: exiting,
                            child: Stack(
                              children: [
                                FadeTransition(
                                  opacity: animation,
                                  child: ModalBarrier(
                                    color: Colors.black.withValues(alpha: .40),
                                    dismissible: true,
                                    onDismiss: cancel,
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.bottomCenter,
                                  child: FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0, 1),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxHeight:
                                              MediaQuery.sizeOf(
                                                context,
                                              ).height *
                                              .85,
                                        ),
                                        child: child,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                child: state == null
                    ? const SizedBox.shrink(
                        key: ValueKey('agent-document-hidden'),
                      )
                    : NativeAgentDocumentSheet(
                        key: ValueKey((owner, state.request)),
                        title: state.request.title,
                        reason: state.request.reason,
                        busy: state.busy,
                        onChoose: choose,
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}
