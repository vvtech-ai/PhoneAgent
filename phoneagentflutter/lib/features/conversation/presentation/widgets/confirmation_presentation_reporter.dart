import 'package:flutter/material.dart';

/// Reports the captured card only after its rendered bounds enter the page.
class ConfirmationPresentationReporter extends StatefulWidget {
  const ConfirmationPresentationReporter({
    super.key,
    required this.child,
    required this.onPresented,
  });
  final Widget child;
  final VoidCallback onPresented;
  @override
  State<ConfirmationPresentationReporter> createState() => _ReporterState();
}

class _ReporterState extends State<ConfirmationPresentationReporter> {
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ModalRoute.of(context)?.isCurrent == false) return;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) return;
      final bounds = box.localToGlobal(Offset.zero) & box.size;
      if (bounds.overlaps(Offset.zero & MediaQuery.sizeOf(context))) {
        widget.onPresented();
      }
    });
    return widget.child;
  }
}
