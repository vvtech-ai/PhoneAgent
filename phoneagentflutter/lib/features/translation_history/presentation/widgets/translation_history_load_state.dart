import '../../../../core/design/native_action_style.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// First-load presentation only; previously loaded content owns its refresh UI.
class TranslationHistoryLoadState extends StatelessWidget {
  const TranslationHistoryLoadState({
    super.key,
    required this.loading,
    required this.failed,
    required this.closeButton,
    required this.onRetry,
  });
  final bool loading, failed;
  final Widget closeButton;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      if (loading)
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              math.max(28, MediaQuery.textScalerOf(context).scale(32) + 37),
              28,
              math.max(28, MediaQuery.textScalerOf(context).scale(32) + 37),
              0,
            ),
            child: const Text(
              '正在加载记录',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 17 / 14,
                letterSpacing: 0,
                color: Color(0xFF98A2B3),
              ),
            ),
          ),
        )
      else if (failed)
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '记录加载失败',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 17 / 14,
                    letterSpacing: 0,
                    color: Color(0xFF6E6E73),
                  ),
                ),
                const SizedBox(height: 12),
                NativeActionSurface(
                  child: FilledButton(
                    key: const ValueKey('retry-translation'),
                    onPressed: onRetry,
                    child: const Text('重试'),
                  ),
                ),
              ],
            ),
          ),
        ),
      Positioned(top: 18, right: 20, child: closeButton),
    ],
  );
}
