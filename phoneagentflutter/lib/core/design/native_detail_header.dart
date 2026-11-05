import 'package:flutter/material.dart';

/// AssistantBackTitleBar / AISettingsPageHeader. The parent owns SafeArea.
class NativeDetailHeader extends StatelessWidget {
  const NativeDetailHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.showBack = true,
    this.backLabel = '返回',
    this.backKey,
    this.trailing,
    this.wrapTitle = false,
    this.color = const Color(0xFF111111),
  });
  final String title;
  final VoidCallback? onBack;
  final bool showBack;
  final String backLabel;
  final Key? backKey;
  final Widget? trailing;
  final bool wrapTitle;
  final Color color;

  static double heightFor(TextScaler textScaler) =>
      16 + (textScaler.scale(28) * 40 / 28).clamp(40.0, double.infinity);

  void _back(BuildContext context) {
    if (!context.mounted || ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    onBack?.call();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Row(
            children: [
              const SizedBox(width: 28, height: 40),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: wrapTitle ? null : 1,
                    overflow: wrapTitle
                        ? TextOverflow.clip
                        : TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 28,
                      height: 40 / 28,
                      letterSpacing: 0,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ),
              if (trailing == null)
                const SizedBox(width: 40, height: 40)
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth:
                        (constraints.maxWidth - 64).clamp(0, double.infinity) /
                        2,
                    maxHeight: heightFor(MediaQuery.textScalerOf(context)) - 16,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: trailing,
                  ),
                ),
            ],
          ),
        ),
        if (showBack)
          Positioned(
            left: 8,
            top: 4,
            width: 48,
            bottom: 4,
            child: Center(
              child: SizedBox.square(
                dimension: 48,
                child: Semantics(
                  container: true,
                  button: true,
                  enabled: onBack != null,
                  label: backLabel,
                  onTap: onBack == null ? null : () => _back(context),
                  excludeSemantics: true,
                  child: IconButton(
                    key: backKey,
                    tooltip: backLabel,
                    padding: EdgeInsets.zero,
                    onPressed: onBack == null ? null : () => _back(context),
                    icon: Transform.translate(
                      offset: const Offset(0, -2),
                      child: Text(
                        '‹',
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontSize: 30,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
