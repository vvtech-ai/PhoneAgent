import '../../../../core/design/native_confirmation_dialog.dart';
import 'package:flutter/material.dart';
import '../../data/preview_receipts.dart';
import '../../domain/conversation_messages.dart';
import '../controller/preview_call_recording_session.dart';
import '../controller/conversation_state.dart';
import 'conversation_page.dart';
import '../../../translation_history/data/preview_recording_audio.dart';
import '../widgets/receipts/preview_call_recording.dart';

class ReceiptPreviewPage extends StatefulWidget {
  const ReceiptPreviewPage({super.key});
  @override
  State<ReceiptPreviewPage> createState() => _ReceiptPreviewPageState();
}

class _ReceiptPreviewPageState extends State<ReceiptPreviewPage>
    with WidgetsBindingObserver {
  late final _recordings = createPreviewCallRecordings(
    _chooseRecordingDestination,
  );
  bool _running = true, _voice = true;
  final _messages = <ConversationMessage>[];
  String _notice = '';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _recordings.setForeground(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordings.dispose();
    super.dispose();
  }

  Future<bool> _chooseRecordingDestination() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => NativeConfirmationDialog(
          title: 'MOCK · 保存本次录音',
          message: '模拟先选择保存位置，再获取录音，不写真实文件。',
          dismissLabel: '取消保存',
          confirmLabel: '模拟保存',
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          const Text(
            'MOCK · 回执与录音演练，无服务、电话、费用、声音或文件操作',
            textAlign: TextAlign.center,
          ),
          TextButton(
            onPressed: () => setState(() => _running = !_running),
            child: Text(_running ? '模拟收到批量终态' : '重新演练运行态'),
          ),
          Expanded(
            child: ConversationPage(
              state: ConversationState(
                entry: const ConversationEntry(sessionId: 'preview:receipts'),
                messages: [
                  ...previewReceipts(running: _running),
                  ..._messages,
                ],
                voiceMode: _voice,
                notice: _notice,
              ),
              modelName: '合成模型',
              recordingBuilder: (callId, compact) => PreviewCallRecording(
                key: ValueKey('mock-recording:$callId'),
                compact: compact,
                manager: _recordings,
                callId: callId,
                scenario: callId == 'preview-failure'
                    ? RecordingPreviewScenario.loadFailure
                    : RecordingPreviewScenario.normal,
              ),
              onClose: () => Navigator.pop(context),
              onToggle: () {
                if (!_voice) _recordings.stopPlayback();
                setState(() => _voice = !_voice);
              },
              onSend: (text) {
                setState(() {
                  _messages.add(
                    ConversationMessage(
                      id: 'preview:message:${_messages.length}',
                      role: MessageRole.user,
                      text: text,
                    ),
                  );
                  _notice = 'MOCK · 文字只保留在演练页面，没有网络请求';
                });
                return true;
              },
              onChoose: (_, _) => false,
              onRetry: () {},
              onNotice: (text) => setState(() => _notice = text),
              onModels: () => setState(() => _notice = '演练固定合成模型，不改变账号配置'),
            ),
          ),
        ],
      ),
    ),
  );
}
