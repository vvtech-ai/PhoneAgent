import 'dart:async';
import 'package:flutter/material.dart';
import '../../../contacts/domain/contact_name_matcher.dart';
import '../../data/voice/preview_voice_input.dart';
import '../../data/voice/preview_reply_speech.dart';
import '../../domain/voice/voice_gateway_event.dart';
import '../controller/conversation_controller.dart';
import '../controller/conversation_state.dart';
import '../controller/voice_input_controller.dart';
import '../controller/conversation_speech_controller.dart';
import '../widgets/voice_composer_binding.dart';
import 'conversation_page.dart';

class VoiceInputPreviewPage extends StatefulWidget {
  const VoiceInputPreviewPage({super.key});
  @override
  State<VoiceInputPreviewPage> createState() => _VoiceInputPreviewPageState();
}

class _VoiceInputPreviewPageState extends State<VoiceInputPreviewPage>
    with WidgetsBindingObserver {
  final _ports = PreviewVoiceInput();
  final _speechPorts = PreviewReplySpeech();
  late final ConversationSpeechController _speech;
  late final ConversationController _conversation;
  late final VoiceInputController _voice;
  late ConversationState _state;
  late final VoidCallback _remove;
  int _id = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _conversation = ConversationController(
      entry: const ConversationEntry(sessionId: 'mock-voice-input'),
      accountId: 'isolated-mock',
      gateway: _ports,
      history: _ports,
      nextId: () => 'mock-voice-${++_id}',
    );
    _remove = _conversation.addListener((state) {
      _state = state;
      if (mounted) setState(() {});
    });
    _speech = ConversationSpeechController(
      factory: _speechPorts.create,
      enabled: () => mounted && _conversation.isOpen,
    )..addListener(_refresh);
    _conversation.speech = _speech;
    _voice = VoiceInputController(
      createSession: _ports.create,
      permissions: _ports,
      endpoint: Uri.parse('wss://synthetic.invalid/asr'),
      isCurrent: () => mounted && _conversation.isOpen,
      canSubmit: () => _state.canSend && _state.voiceMode,
      recoveryText: () => _conversation.recoverableInput,
      submit: (text) =>
          _conversation.send(text, source: ContactInputSource.asr),
    )..addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(_voice.cancel());
      unawaited(_speech.interrupt());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _voice.removeListener(_refresh);
    _voice.dispose();
    _speech.removeListener(_refresh);
    _remove();
    _conversation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'MOCK · 不录音、不出声、不联网、不修改账号 · 请求 ${_ports.commands.length} 次 · 识别回退 ${_ports.fallbackStarts} 次',
            ),
          ),
          if (MediaQuery.viewInsetsOf(context).bottom == 0)
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
                  onPressed: () => _ports.latest?.emit(
                    const VoiceTranscript('帮我整理明天的安排', isFinal: true),
                  ),
                  child: const Text('模拟 final'),
                ),
                PopupMenuButton<String>(
                  tooltip: '模拟异常',
                  onSelected: (value) => setState(() {
                    if (value == 'asr') {
                      _ports.latest?.emit(
                        const VoiceGatewayFailure('synthetic'),
                      );
                    } else if (value == 'fallback' ||
                        value == 'fallback-fail') {
                      _ports.failPrimaryRecognition = true;
                      _ports.failBackupRecognition = value == 'fallback-fail';
                    } else if (value == 'normal') {
                      _ports.failNextCommand = _ports.failHistory = false;
                      _ports.failPrimaryRecognition =
                          _ports.failBackupRecognition = false;
                    } else {
                      _ports.recoveryScenario(
                        committed: value == 'committed',
                        historyFails: value == 'history',
                      );
                    }
                  }),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'asr', child: Text('识别连接断开')),
                    PopupMenuItem(value: 'fallback', child: Text('下次识别：备用成功')),
                    PopupMenuItem(
                      value: 'fallback-fail',
                      child: Text('下次识别：备用也失败'),
                    ),
                    PopupMenuItem(value: 'pending', child: Text('下次提交断网：尚未完成')),
                    PopupMenuItem(
                      value: 'committed',
                      child: Text('下次提交断网：后台已完成'),
                    ),
                    PopupMenuItem(value: 'history', child: Text('下次断网且历史同步失败')),
                    PopupMenuItem(value: 'normal', child: Text('恢复正常连接')),
                  ],
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('模拟异常'),
                  ),
                ),
                TextButton(
                  onPressed: _voice.state.canPress
                      ? () => setState(
                          () => _ports.denyPermission = !_ports.denyPermission,
                        )
                      : null,
                  child: Text(_ports.denyPermission ? '权限：拒绝' : '权限：允许'),
                ),
              ],
            ),
          Expanded(
            child: ConversationPage(
              state: _state,
              modelName: 'MOCK',
              voice: VoiceComposerBinding(
                state: _voice.state,
                speechStatus: _speech.status,
                canInterruptReply: _speech.isActive,
                onStopSpeech: () => unawaited(_speech.interrupt()),
                onPress: () {
                  _conversation.interruptReplyForInput();
                  unawaited(_voice.press());
                },
                onRelease: _voice.release,
                onCancel: () => unawaited(_voice.cancel()),
              ),
              onClose: () {
                unawaited(_voice.cancel());
                Navigator.maybePop(context);
              },
              onToggle: () {
                unawaited(_voice.cancel());
                _conversation.toggleInput();
              },
              onSend: _conversation.send,
              onChoose: _conversation.choose,
              onRetry: _conversation.restore,
              onNotice: _conversation.showNotice,
              onModels: () => _conversation.showNotice('隔离演练不修改通话模型'),
            ),
          ),
        ],
      ),
    ),
  );
}
