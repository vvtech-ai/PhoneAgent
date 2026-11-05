import 'package:flutter/material.dart';
import '../../data/preview_batch_stream.dart';
import '../controller/conversation_controller.dart';
import '../controller/conversation_state.dart';
import '../controller/detached_batch_streams.dart';
import 'conversation_page.dart';

class BatchFlowPreviewPage extends StatefulWidget {
  const BatchFlowPreviewPage({super.key});
  @override
  State<BatchFlowPreviewPage> createState() => _BatchFlowPreviewPageState();
}

class _BatchFlowPreviewPageState extends State<BatchFlowPreviewPage> {
  final _ports = PreviewBatchStream();
  late final _detached = DetachedBatchStreams(
    onFinished: () {
      if (mounted) setState(() {});
    },
  );
  Future<void> _open(bool restore) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _Conversation(ports: _ports, detached: _detached, restore: restore),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _detached.close();
    _ports.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('批量进度与退出演练')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('MOCK · 共用正式控制器，无网络、电话、费用或账号写入'),
          Text('活动接收：${_detached.count}'),
          Text(_ports.completed ? '合成历史：已有最终结果' : '合成历史：等待最终结果'),
          OutlinedButton(
            onPressed: () => _open(false),
            child: const Text('进入统一页并发送合成需求'),
          ),
          OutlinedButton(
            onPressed: () => _open(true),
            child: const Text('从合成任务列表恢复'),
          ),
          OutlinedButton(
            onPressed: () {
              _ports.finish();
              setState(() {});
            },
            child: const Text('模拟退出后结果到达'),
          ),
          OutlinedButton(
            onPressed: () {
              _detached.close();
              setState(() {});
            },
            child: const Text('模拟账号释放'),
          ),
        ],
      ),
    ),
  );
}

class _Conversation extends StatefulWidget {
  const _Conversation({
    required this.ports,
    required this.detached,
    required this.restore,
  });
  final PreviewBatchStream ports;
  final DetachedBatchStreams detached;
  final bool restore;
  @override
  State<_Conversation> createState() => _ConversationState();
}

class _ConversationState extends State<_Conversation> {
  late final ConversationController _controller;
  late final void Function() _remove;
  late ConversationState _state;
  @override
  void initState() {
    super.initState();
    _controller = ConversationController(
      entry: const ConversationEntry(sessionId: 'mock-batch-session'),
      accountId: 'mock-owner',
      gateway: widget.ports,
      history: widget.ports,
      detachedBatches: widget.detached,
    );
    _remove = _controller.addListener((value) {
      _state = value;
      if (mounted) setState(() {});
    });
    if (widget.restore) {
      _controller.restore();
    } else {
      _controller.send('请执行合成批量任务');
    }
  }

  @override
  void dispose() {
    _remove();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) _controller.close();
    },
    child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Text('MOCK · 真实SSE格式、共享页面和状态，无真实外呼'),
            Wrap(
              children: [
                TextButton(
                  onPressed: widget.ports.advance,
                  child: const Text('推送逐项进度'),
                ),
                TextButton(
                  onPressed: widget.ports.finish,
                  child: const Text('推送最终结果'),
                ),
                TextButton(
                  onPressed: widget.ports.fail,
                  child: const Text('模拟断流'),
                ),
              ],
            ),
            Expanded(
              child: ConversationPage(
                state: _state,
                modelName: '合成模型',
                onClose: () => Navigator.pop(context),
                onToggle: _controller.toggleInput,
                onSend: _controller.send,
                onChoose: _controller.choose,
                onRetry: _controller.restore,
                onNotice: _controller.showNotice,
                onModels: () => _controller.showNotice('MOCK · 不修改账号模型'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
