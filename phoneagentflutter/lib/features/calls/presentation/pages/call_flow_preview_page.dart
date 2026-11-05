import 'package:flutter/material.dart';
import '../../data/preview_call_flow.dart';
import '../../data/preview_call_monitor.dart';
import '../widgets/call_monitor_preview_controls.dart';
import '../../../conversation/presentation/controller/conversation_controller.dart';
import '../../../conversation/presentation/controller/conversation_state.dart';
import '../../../conversation/presentation/pages/conversation_page.dart';
import '../../../conversation/data/voice/preview_reply_speech.dart';
import '../../../conversation/presentation/controller/conversation_speech_controller.dart';
import 'conversation_call_host.dart';
import '../../../conversation/presentation/widgets/call_confirmation_card.dart';
import '../../../conversation/presentation/widgets/batch_confirmation_card.dart';
import '../../../conversation/presentation/widgets/confirmation_presentation_reporter.dart';

class CallFlowPreviewPage extends StatefulWidget {
  const CallFlowPreviewPage({super.key, required this.scenario});
  final CallFlowScenario scenario;
  @override
  State<CallFlowPreviewPage> createState() => _CallFlowPreviewPageState();
}

class _CallFlowPreviewPageState extends State<CallFlowPreviewPage>
    with WidgetsBindingObserver {
  late final PreviewCallFlow _ports;
  late final ConversationController _conversation;
  late final void Function() _remove;
  late ConversationState _state;
  final _speechPorts = PreviewReplySpeech();
  late final ConversationSpeechController _speech;
  final _monitorPorts = PreviewCallMonitor();
  void Function()? _removeCall;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ports = PreviewCallFlow(widget.scenario, narrateResults: true);
    _conversation = ConversationController(
      entry: const ConversationEntry(sessionId: 'mock-call-flow'),
      accountId: 'mock-owner',
      gateway: _ports,
      history: _ports,
      callAdmission: _ports.admission,
      callSessions: _ports,
    );
    _speech = _conversation.speech = ConversationSpeechController(
      factory: _speechPorts.create,
      enabled: () =>
          mounted &&
          _conversation.isOpen &&
          _conversation.calls?.snapshot.showCall != true,
    )..addListener(_refresh);
    _removeCall = _conversation.calls?.addListener((call) {
      if (call.showCall) {
        _speech.pauseForCall();
      } else {
        _speech.resumeResult();
      }
    });
    _remove = _conversation.addListener((value) {
      _state = value;
      if (mounted) setState(() {});
    });
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _speech.interrupt();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _removeCall?.call();
    _speech.removeListener(_refresh);
    _remove();
    _conversation.dispose();
    _monitorPorts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          const Text('MOCK · 整条链路离线，不拨号、不扣费', textAlign: TextAlign.center),
          CallMonitorPreviewControls(ports: _monitorPorts),
          Text('合成播报：${_speech.status.isEmpty ? '空闲' : _speech.status} · 不出声'),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              TextButton(
                onPressed: () => _speechPorts.output?.consume(),
                child: const Text('模拟播完'),
              ),
              TextButton(
                onPressed: () => _speechPorts.output?.fail(),
                child: const Text('模拟播放失败'),
              ),
              TextButton(
                onPressed: () => _conversation.send('请确认合成预约'),
                child: const Text('发送合成需求'),
              ),
              TextButton(
                onPressed: () => _conversation.calls?.confirm('确认拨打'),
                child: const Text('确认合成拨打'),
              ),
              TextButton(
                onPressed: () {
                  _ports.ended = true;
                },
                child: const Text('合成远端结束'),
              ),
              TextButton(
                onPressed: () {
                  _ports.ended = true;
                  _ports.outcomeReady = true;
                },
                child: const Text('合成结果到达'),
              ),
              TextButton(
                onPressed: _conversation.restore,
                child: const Text('恢复合成历史'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('退出演练'),
              ),
            ],
          ),
          Expanded(
            child: ConversationCallHost(
              createMonitor: _monitorPorts.create,
              controller: _conversation.calls,
              modelName: '合成模型 · MOCK',
              child: ConversationPage(
                confirmationBuilder: (message, _) {
                  final request = _conversation.calls?.snapshot.launch.request;
                  final card = message.batchConfirmation != null
                      ? BatchConfirmationCard(
                          confirmation: message.batchConfirmation!,
                        )
                      : CallConfirmationCard(
                          confirmation: message.confirmation!,
                        );
                  if (request == null || request.toolId != message.toolCallId) {
                    return card;
                  }
                  return ConfirmationPresentationReporter(
                    key: ValueKey(request.identity),
                    child: card,
                    onPresented: () =>
                        _conversation.reportConfirmationPresented(
                          request.identity,
                          request.specSignature,
                        ),
                  );
                },
                state: _state,
                modelName: '合成模型',
                onClose: () => Navigator.pop(context),
                onToggle: _conversation.toggleInput,
                onSend: _conversation.send,
                onChoose: _conversation.choose,
                onRetry: _conversation.restore,
                onNotice: _conversation.showNotice,
                onModels: () => _conversation.showNotice('MOCK · 不修改账号模型'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class CallFlowScenariosPage extends StatelessWidget {
  const CallFlowScenariosPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('对话到通话全流程演练')),
    body: ListView(
      children: [
        for (final pair in const {
          CallFlowScenario.single: '单路明确确认 → 通话 → 回执',
          CallFlowScenario.batch: '多路确认 → 留在对话页',
          CallFlowScenario.insufficient: '首次不足提示 → 再次不足弹框',
          CallFlowScenario.uncertain: '确认网络异常 → 只同步不重发',
          CallFlowScenario.modelFailure: '模型超时 → 收起通话可继续输入',
          CallFlowScenario.liveResult: '实时结果到达 → 直接返回统一页',
        }.entries)
          ListTile(
            title: Text(pair.value),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => CallFlowPreviewPage(scenario: pair.key),
              ),
            ),
          ),
      ],
    ),
  );
}
