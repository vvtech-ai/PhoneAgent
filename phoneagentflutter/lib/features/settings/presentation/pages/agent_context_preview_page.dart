import 'dart:convert';
import 'package:flutter/material.dart';
import '../controller/agent_context_preview_controller.dart';

class AgentContextPreviewPage extends StatefulWidget {
  const AgentContextPreviewPage({super.key});
  @override
  State<AgentContextPreviewPage> createState() =>
      _AgentContextPreviewPageState();
}

class _AgentContextPreviewPageState extends State<AgentContextPreviewPage> {
  final controller = AgentContextPreviewController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('对话上下文演练')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('MOCK · 合成时间、位置及权限；不请求系统权限、不发送真实对话'),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: controller.zone,
              decoration: const InputDecoration(labelText: '合成时区'),
              items: [
                for (final zone in AgentContextPreviewController.zones)
                  DropdownMenuItem(value: zone, child: Text(zone)),
              ],
              onChanged: controller.busy
                  ? null
                  : (value) => controller.setZone(value!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: controller.mode,
              decoration: const InputDecoration(labelText: '合成权限状态'),
              items: [
                for (final mode in AgentContextPreviewController.modes)
                  DropdownMenuItem(value: mode, child: Text(mode)),
              ],
              onChanged: controller.busy
                  ? null
                  : (value) => controller.setMode(value!),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: controller.busy ? null : controller.prepare,
              child: const Text('组装下一轮上下文'),
            ),
            OutlinedButton(
              onPressed: controller.busy ? null : controller.advanceDay,
              child: const Text('合成时钟推进一天'),
            ),
            Text('已组装 ${controller.turns} 轮 · 每轮重新读取，文档选择器无需全盘授权'),
            const SizedBox(height: 12),
            SelectableText(
              const JsonEncoder.withIndent('  ').convert(controller.result),
            ),
          ],
        ),
      ),
    ),
  );
}
