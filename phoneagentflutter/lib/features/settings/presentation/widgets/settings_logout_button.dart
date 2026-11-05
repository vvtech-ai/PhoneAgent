import 'package:flutter/material.dart';

/// Settings footer matching Android SettingsLogoutAction.
class SettingsLogoutButton extends StatelessWidget {
  const SettingsLogoutButton({
    super.key,
    required this.onTap,
    this.loginPhone = '未登录',
  });
  final VoidCallback onTap;
  final String loginPhone;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Semantics(
      label: '退出登录',
      value: loginPhone,
      button: true,
      enabled: true,
      onTap: onTap,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14101114),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: const Color(0xCCFFFFFF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xC7FFFFFF)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const title = Text(
                      '退出登录',
                      style: TextStyle(
                        color: Color(0xFFFF3B30),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                    final phone = Text(
                      loginPhone,
                      style: const TextStyle(
                        color: Color(0xFF8A8F99),
                        fontSize: 13,
                      ),
                    );
                    final scaler = MediaQuery.textScalerOf(context);
                    double textWidth(Text text) {
                      final painter = TextPainter(
                        text: TextSpan(text: text.data, style: text.style),
                        textDirection: Directionality.of(context),
                        textScaler: scaler,
                      )..layout();
                      final width = painter.width;
                      painter.dispose();
                      return width;
                    }

                    if (constraints.maxWidth <
                        textWidth(title) + textWidth(phone) + 16) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [title, const SizedBox(height: 8), phone],
                      );
                    }
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [title, const SizedBox(width: 16), phone],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
