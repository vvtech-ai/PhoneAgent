import 'package:flutter/material.dart';
import '../../../identity/presentation/widgets/identity_widgets.dart';

class InitializationHeader extends StatelessWidget {
  const InitializationHeader({
    super.key,
    required this.showBack,
    required this.showSkip,
    required this.busy,
    required this.onBack,
    required this.onSkip,
  });

  final bool showBack, showSkip, busy;
  final VoidCallback onBack, onSkip;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 48),
    child: Stack(
      alignment: Alignment.center,
      children: [
        const SizedBox(
          width: double.infinity,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 76, vertical: 12),
            child: Text(
              '初始化设置',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                height: 22 / 18,
                letterSpacing: 0,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111111),
              ),
            ),
          ),
        ),
        if (showBack)
          Positioned(
            left: 12,
            top: 0,
            bottom: 0,
            child: Center(
              child: IdentityIconButton(
                label: '返回上一步',
                asset: 0,
                onTap: busy ? null : onBack,
              ),
            ),
          ),
        if (showSkip)
          Positioned(
            right: 18,
            top: 0,
            bottom: 0,
            child: Center(
              child: TextButton(
                onPressed: busy ? null : onSkip,
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: EdgeInsets.zero,
                  foregroundColor: const Color(0xFF667085),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    height: 17 / 14,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: const Text('跳过'),
              ),
            ),
          ),
      ],
    ),
  );
}
