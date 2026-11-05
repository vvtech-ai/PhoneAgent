import 'package:flutter/material.dart';

/// AssistantBackTitleBar / AISettingsPageHeader. The parent owns SafeArea.
class NativeDetailHeader extends StatelessWidget {
  const NativeDetailHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.backKey,
    this.trailing,
    this.wrapTitle = false,
    this.color = const Color(0xFF111111),
  });
  final String title;
  final VoidCallback? onBack;
  final Key? backKey;
  final Widget? trailing;
  final bool wrapTitle;
  final Color color;

  void _back(BuildContext context) {
    if (!context.mounted || ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    onBack?.call();
  }

  @override
  Widget build(BuildContext context) => Stack(
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
            trailing ?? const SizedBox(width: 40, height: 40),
          ],
        ),
      ),
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
              label: '返回',
              onTap: onBack == null ? null : () => _back(context),
              excludeSemantics: true,
              child: IconButton(
                key: backKey,
                tooltip: '返回',
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
  );
}
