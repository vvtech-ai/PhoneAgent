import 'package:flutter/material.dart';
import '../../../../core/design/native_page_header.dart';

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
  Widget build(BuildContext context) => NativePageHeader(
    title: '初始化设置',
    showBack: showBack,
    backLabel: '返回上一步',
    onBack: busy ? null : onBack,
    trailing: showSkip
        ? TextButton(
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
          )
        : null,
  );
}
