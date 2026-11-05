import 'package:flutter/material.dart';
import '../../../../core/design/native_page_header.dart';
import '../../../../core/design/native_card_style.dart';
import '../../../../core/design/native_page_background.dart';

abstract final class MemoryColors {
  static const background = Color(0xFFF7F8FB),
      text = Color(0xFF0F172A),
      secondary = Color(0xFF8A94A4),
      blue = Color(0xFF1473FF),
      lightBlue = Color(0xFFEAF3FF),
      divider = Color(0xFFEEF0F4),
      red = Color(0xFFEF4444);
}

class MemoryFrame extends StatelessWidget {
  const MemoryFrame({
    super.key,
    required this.title,
    required this.busy,
    required this.body,
    this.action,
    this.error = '',
    this.retryLabel = '重试',
    this.onRetry,
    this.onBack,
  });
  final String title, error, retryLabel;
  final bool busy;
  final Widget body;
  final Widget? action;
  final VoidCallback? onRetry, onBack;
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      backgroundColor: MemoryColors.background,
      body: NativePageBackground(
        child: SafeArea(
          child: Column(
            children: [
              NativePageHeader(
                title: title,
                onBack: busy
                    ? null
                    : onBack ?? () => Navigator.maybePop(context),
                trailing: action,
              ),
              if (error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          error,
                          style: const TextStyle(
                            fontSize: 13,
                            color: MemoryColors.red,
                          ),
                        ),
                      ),
                      if (onRetry != null)
                        TextButton(
                          onPressed: busy ? null : onRetry,
                          child: Text(
                            retryLabel,
                            style: const TextStyle(color: MemoryColors.blue),
                          ),
                        ),
                    ],
                  ),
                ),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    ),
  );
}

class MemoryCard extends StatelessWidget {
  const MemoryCard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: NativeCardStyle.decoration,
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: child,
    ),
  );
}
