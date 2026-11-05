import 'package:flutter/material.dart';
import '../../data/tools/preview_permission_session.dart';
import '../controller/conversation_controller.dart';
import '../controller/conversation_state.dart';
import 'conversation_page.dart';

class PermissionPreviewPage extends StatefulWidget {
  const PermissionPreviewPage({super.key});
  @override
  State<PermissionPreviewPage> createState() => _PermissionPreviewPageState();
}

class _PermissionPreviewPageState extends State<PermissionPreviewPage> {
  final _ports = PreviewPermissionSession();
  late final ConversationController _controller;
  late ConversationState _state;
  late void Function() _remove;
  var _id = 0;

  @override
  void initState() {
    super.initState();
    _controller = ConversationController(
      entry: const ConversationEntry(
        sessionId: 'mock-permission',
        opening: '切换到文字输入，发送任意文字体验权限结果续接。',
      ),
      accountId: 'isolated-mock',
      gateway: _ports,
      history: _ports,
      permissions: _ports,
      nextId: () => 'mock-${++_id}',
    );
    _remove = _controller.addListener((state) {
      _state = state;
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _remove();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('MOCK · 权限工具演练，不申请系统权限，不读取私人数据。'),
          ),
          DropdownButton<PermissionPreviewScenario>(
            value: _ports.scenario,
            items: [
              for (final entry in const {
                PermissionPreviewScenario.allow: '模拟允许',
                PermissionPreviewScenario.deny: '模拟拒绝',
                PermissionPreviewScenario.settings: '模拟不可用/需设置',
                PermissionPreviewScenario.alreadyGranted: '模拟已授权',
              }.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: !_state.canSend
                ? null
                : (value) {
                    if (value != null) setState(() => _ports.scenario = value);
                  },
          ),
          Expanded(
            child: ConversationPage(
              state: _state,
              modelName: 'MOCK',
              onClose: () => Navigator.pop(context),
              onToggle: _controller.toggleInput,
              onSend: _controller.send,
              onChoose: _controller.choose,
              onRetry: _controller.restore,
              onNotice: _controller.showNotice,
              onModels: () => _controller.showNotice('演练不修改通话模型'),
              onAttachments: () => _controller.showNotice('本演练只验证权限工具'),
            ),
          ),
        ],
      ),
    ),
  );
}
