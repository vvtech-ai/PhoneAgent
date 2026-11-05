import 'package:flutter/material.dart';
import '../controller/translation_setup_controller.dart';

class TranslationStorageStatus extends StatelessWidget {
  const TranslationStorageStatus({super.key, required this.controller});
  final TranslationSetupController controller;

  @override
  Widget build(BuildContext context) {
    final status = controller.status;
    final message = status.error.isNotEmpty
        ? status.error
        : status.loading
        ? '正在读取翻译配置…'
        : null;
    if (message == null && status.error.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message != null)
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF946200)),
            ),
          if (status.error.isNotEmpty)
            TextButton(
              onPressed: status.ready ? controller.save : controller.load,
              child: Text(status.ready ? '重试保存' : '重试读取'),
            ),
        ],
      ),
    );
  }
}
