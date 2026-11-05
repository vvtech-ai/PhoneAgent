import 'package:flutter/material.dart';
import '../controller/call_preview_controller.dart';
import '../widgets/call_controls.dart';
import 'call_session_page.dart';

class CallPreviewRoute extends StatefulWidget {
  const CallPreviewRoute({super.key, required this.scenario});
  final CallPreviewScenario scenario;
  @override
  State<CallPreviewRoute> createState() => _CallPreviewRouteState();
}

class _CallPreviewRouteState extends State<CallPreviewRoute> {
  late final CallPreviewController _controller;
  late final void Function() _removeListener;
  @override
  void initState() {
    super.initState();
    _controller = CallPreviewController(widget.scenario);
    _removeListener = _controller.addListener((_) {
      if (mounted) setState(() {});
    }, fireImmediately: false);
  }

  @override
  void dispose() {
    _removeListener();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _hangup() async {
    if (await _controller.hangUp() && mounted) Navigator.pop(context);
  }

  Future<void> _source() async {
    final result = await showCallAudioSources(
      context,
      _controller.snapshot.monitor,
      preview: true,
    );
    if (mounted && result != null) _controller.source(result);
  }

  Future<void> _actions() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('MOCK · 合成事件，不操作真实电话'),
              ),
              for (final label in [
                '模拟接通',
                '追加转写',
                '恢复状态查询',
                '模拟远端结束',
                '模拟任务结果到达',
                '下次监听失败',
                '模拟监听重连',
              ])
                ListTile(
                  title: Text(label),
                  onTap: () => Navigator.pop(context, label),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case '模拟接通':
        await _controller.connected();
      case '追加转写':
        await _controller.transcript();
      case '恢复状态查询':
        await _controller.recoverPolling();
      case '模拟远端结束':
        await _controller.remoteEnd();
      case '模拟任务结果到达':
        _controller.outcome();
      case '下次监听失败':
        _controller.failNextMonitor = true;
      case '模拟监听重连':
        await _controller.reconnect();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.snapshot;
    return Scaffold(
      body: CallSessionPage(
        state: state.call,
        monitor: state.monitor,
        seconds: state.seconds,
        modelName: 'Seeduplex · MOCK',
        onMonitor: _controller.toggleMonitor,
        onHangup: _hangup,
        onSource: _source,
        previewHeader: Column(
          children: [
            const Text(
              'MOCK · 无真实外呼、监听音频或设备切换',
              style: TextStyle(color: Color(0xFFFFC978), fontSize: 11),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('退出演练'),
                ),
                TextButton(onPressed: _actions, child: const Text('演练控制')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CallPreviewScenariosPage extends StatelessWidget {
  const CallPreviewScenariosPage({super.key});
  static const labels = {
    CallPreviewScenario.dialing: '呼叫中 → 接通 → 转写',
    CallPreviewScenario.connected: '已接通 · 监听与音源',
    CallPreviewScenario.bluetooth: '蓝牙可用 · 音源选择',
    CallPreviewScenario.pollingError: '状态同步失败与恢复',
    CallPreviewScenario.hangupError: '挂断失败与显式重试',
    CallPreviewScenario.awaitingOutcome: '通话结束 · 等待任务结果',
  };
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('单路通话页面演练')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('MOCK · 使用共享通话页面和状态控制器，但所有服务和媒体状态均为合成；不会拨号、挂断真实电话或申请权限。'),
          for (final entry in labels.entries)
            ListTile(
              title: Text(entry.value),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => CallPreviewRoute(scenario: entry.key),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
