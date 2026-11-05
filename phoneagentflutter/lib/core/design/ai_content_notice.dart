import 'package:flutter/material.dart';

/// Presentation-only disclosure. Only this text opts out of system scaling.
class AiContentNotice extends StatelessWidget {
  const AiContentNotice.light({super.key}) : _dark = false;
  const AiContentNotice.dark({super.key}) : _dark = true;

  static const bottomSpacing = 20.0;
  static const keyboardSpacing = 8.0;

  /// Only inspect the owning view's original inset. SafeArea can consume the
  /// subtree's MediaQuery padding; the inset itself is never added here.
  static double iosSafeAreaAdjustment(BuildContext context) =>
      Theme.of(context).platform == TargetPlatform.iOS &&
          View.of(context).viewPadding.bottom > 0
      ? 10.0
      : 0.0;

  final bool _dark;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      '内容由AI生成',
      textAlign: TextAlign.center,
      textScaler: TextScaler.noScaling,
      style: TextStyle(
        fontSize: 11,
        color: _dark
            ? const Color.fromRGBO(255, 255, 255, .34)
            : const Color(0xFFB0B4C3),
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.normal,
      ),
      softWrap: true,
    ),
  );
}
