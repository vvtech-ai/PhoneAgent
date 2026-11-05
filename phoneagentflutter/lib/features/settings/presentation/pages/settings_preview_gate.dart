import 'package:flutter/material.dart';

class SettingsPreviewGate extends StatelessWidget {
  const SettingsPreviewGate({
    super.key,
    required this.title,
    required this.explanation,
    required this.preview,
  });
  final String title, explanation;
  final Widget preview;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Text(explanation),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.of(
              context,
            ).push<void>(MaterialPageRoute(builder: (_) => preview)),
            child: const Text('进入隔离交互演练（MOCK）'),
          ),
          const SizedBox(height: 12),
          const Text('演练结果不代表真实功能已完成，退出后不保留模拟数据。'),
        ],
      ),
    ),
  );
}
