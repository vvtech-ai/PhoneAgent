import 'package:flutter/material.dart';
import 'package:phone_agent/features/attachments/presentation/controller/agent_document_controller.dart';
import 'package:phone_agent/features/attachments/presentation/widgets/agent_document_host.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_page.dart';
import 'agent_document_preview_ports.dart';

class AgentDocumentPreviewPage extends StatefulWidget {
  const AgentDocumentPreviewPage({super.key});
  @override
  State<AgentDocumentPreviewPage> createState() =>
      _AgentDocumentPreviewPageState();
}

class _AgentDocumentPreviewPageState extends State<AgentDocumentPreviewPage> {
  final _ports = AgentDocumentPreviewPorts();
  late final _documents = AgentDocumentController(_ports, _ports);
  late final _controller = ConversationController(
    entry: const ConversationEntry(sessionId: 'mock-document'),
    accountId: 'isolated',
    gateway: _ports,
    history: _ports,
    documents: _documents,
  );
  late ConversationState _state;
  late void Function() _remove;
  @override
  void initState() {
    super.initState();
    _remove = _controller.addListener((value) {
      _state = value;
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
      child: AgentDocumentHost(
        controller: _documents,
        child: Column(
          children: [
            const Text('MOCK · Agent文档工具 · 无真实文件/网络'),
            DropdownButton<AgentDocumentScenario>(
              value: _ports.scenario,
              items: [
                for (final entry in const {
                  AgentDocumentScenario.success: '解析成功',
                  AgentDocumentScenario.cancel: '选择取消',
                  AgentDocumentScenario.failure: '解析失败',
                  AgentDocumentScenario.oversized: '文件超限',
                }.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: !_state.canSend
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _ports.scenario = value);
                      }
                    },
            ),
            Wrap(
              spacing: 12,
              children: [
                TextButton(
                  onPressed: _state.canSend
                      ? () => _controller.send('请求文档')
                      : null,
                  child: const Text('触发文档请求'),
                ),
                TextButton(
                  onPressed: _state.canSend
                      ? () => _controller.send('继续')
                      : null,
                  child: const Text('继续文字对话'),
                ),
              ],
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
                onModels: () {},
                onAttachments: () {},
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
