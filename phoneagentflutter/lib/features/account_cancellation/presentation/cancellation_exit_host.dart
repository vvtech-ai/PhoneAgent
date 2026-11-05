import 'package:flutter/material.dart';
import '../../../core/design/native_loading_overlay.dart';
import 'cancellation_controller.dart';
import 'cancellation_exit_controller.dart';
import 'cancellation_verification_page.dart';

/// Stays above the navigator while the old account subtree is really unmounted.
class CancellationExitHost extends StatelessWidget {
  const CancellationExitHost({
    required this.controller,
    required this.signedOut,
    required this.child,
    super.key,
  });
  final CancellationExitController controller;
  final bool signedOut;
  final Widget child;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final frame = controller.frame;
      final visible = frame?.busy == true;
      if (visible && signedOut && frame!.accepted) {
        // Child contains the new login navigator; allow its first layout/paint
        // before removing the inert original-page cover. No timed delay.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted && signedOut) controller.revealLogin(frame.token);
        });
      }
      return Stack(
        fit: StackFit.expand,
        children: [
          ExcludeFocus(
            excluding: visible,
            child: ExcludeSemantics(
              excluding: visible,
              child: IgnorePointer(ignoring: visible, child: child),
            ),
          ),
          if (visible)
            Positioned.fill(
              child: BlockSemantics(
                child: Overlay.wrap(
                  child: _ExitSurface(
                    key: ValueKey(frame!.token),
                    frame: frame,
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _ExitSurface extends StatefulWidget {
  const _ExitSurface({required this.frame, super.key});
  final CancellationExitFrame frame;
  @override
  State<_ExitSurface> createState() => _ExitSurfaceState();
}

class _ExitSurfaceState extends State<_ExitSurface> {
  final _code = TextEditingController();
  final _focus = FocusNode();
  @override
  void dispose() {
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      ExcludeSemantics(
        child: CancellationVerificationPage(
          state: CancellationState(busy: true, cooldown: widget.frame.cooldown),
          maskedPhone: widget.frame.maskedPhone,
          code: _code,
          focusNode: _focus,
          onSend: null,
          onRecover: null,
          onBack: null,
        ),
      ),
      const Positioned.fill(
        child: NativeLoadingOverlay(key: Key('cancellation-exit-loading')),
      ),
    ],
  );
}
