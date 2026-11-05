import 'package:flutter/material.dart';
import '../../data/preview_initialization_gateway.dart';
import '../controller/initialization_controller.dart';
import 'initialization_page.dart';
import '../../../../core/design/native_notice.dart';

class InitializationPreviewRoute extends StatefulWidget {
  const InitializationPreviewRoute({super.key, required this.scenario});
  final InitializationPreviewScenario scenario;
  @override
  State<InitializationPreviewRoute> createState() =>
      _InitializationPreviewRouteState();
}

class _InitializationPreviewRouteState
    extends State<InitializationPreviewRoute> {
  late final InitializationController _controller;
  late final void Function() _removeListener;
  bool _closing = false;
  String _notice = '';
  @override
  void initState() {
    super.initState();
    _controller = InitializationController(
      PreviewInitializationGateway(widget.scenario),
    );
    _removeListener = _controller.addListener((state) {
      if (!mounted) return;
      if (state.notice.isNotEmpty && state.notice != _notice) {
        _notice = state.notice;
        showNativeNotice(context, state.notice);
      }
      setState(() {});
      if (state.finished && !_closing) {
        _closing = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context, true);
        });
      }
    }, fireImmediately: false);
    _controller.load();
  }

  @override
  void dispose() {
    _removeListener();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.snapshot;
    return PopScope(
      canPop: !state.busy && (state.step == 1 || state.finished),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !state.busy) _controller.back();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: InitializationPage(
          state: state,
          onBack: _controller.back,
          onSkip: _controller.skipIdentity,
          onNext: _controller.next,
          onRetry: _controller.load,
          onName: (v) => _controller.edit(name: v),
          onGender: (v) => _controller.edit(gender: v),
          onPhone: (v) => _controller.edit(phone: v),
          onModel: _controller.select,
          previewHeader: Column(
            children: [
              const Text(
                'MOCK · 仅填合成资料，不改变真实身份/模型',
                style: TextStyle(fontSize: 11, color: Color(0xFF946200)),
              ),
              if (state.step == 1)
                TextButton(
                  onPressed: state.busy ? null : () => Navigator.pop(context),
                  child: const Text('退出演练'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class InitializationScenariosPage extends StatefulWidget {
  const InitializationScenariosPage({super.key});
  @override
  State<InitializationScenariosPage> createState() =>
      _InitializationScenariosPageState();
}

class _InitializationScenariosPageState
    extends State<InitializationScenariosPage> {
  String _result = '';
  static const labels = {
    InitializationPreviewScenario.normal: '填写资料与两步完成',
    InitializationPreviewScenario.loadFailure: '加载失败与重试',
    InitializationPreviewScenario.callFailure: '通话模型保存失败',
    InitializationPreviewScenario.identityFailure: '身份保存失败与重试',
    InitializationPreviewScenario.skipFailure: '跳过身份与偏好保存失败',
    InitializationPreviewScenario.existingIdentity: '已有身份不重复引导',
    InitializationPreviewScenario.alreadySkipped: '已跳过不重复引导',
  };
  Future<void> _open(InitializationPreviewScenario scenario) async {
    final completed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => InitializationPreviewRoute(scenario: scenario),
      ),
    );
    if (mounted) {
      setState(
        () => _result = completed == true
            ? 'MOCK · 流程已完成或无需引导，真实账号未改变'
            : 'MOCK · 已退出演练',
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('首次初始化演练')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('MOCK · 合成身份与内存偏好。仅身份与通话模型两步，不改变翻译设置。'),
          if (_result.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(_result),
            ),
          for (final entry in labels.entries)
            ListTile(
              title: Text(entry.value),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(entry.key),
            ),
        ],
      ),
    ),
  );
}
