import 'package:flutter/material.dart';
import '../../data/preview_translation_session.dart';
import '../controller/translation_completion_preview_controller.dart';
import '../widgets/translation_record_save_status.dart';
import '../../../dialer/presentation/widgets/dial_recent_list.dart';
import 'translation_session_route.dart';
import 'livekit_translation_preview_page.dart';
import '../widgets/translation_session_preview_controls.dart';
import 'translation_access_preview_page.dart';

class TranslationSessionPreviewPage extends StatefulWidget {
  const TranslationSessionPreviewPage({super.key});
  @override
  State<TranslationSessionPreviewPage> createState() =>
      _TranslationSessionPreviewPageState();
}

class _TranslationSessionPreviewPageState
    extends State<TranslationSessionPreviewPage> {
  String _result = '';
  final _completion = TranslationCompletionPreviewController();
  @override
  void dispose() {
    _completion.dispose();
    super.dispose();
  }

  Future<void> _open(String scenario) async {
    final fixture = PreviewTranslationSession(scenario: scenario);
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => TranslationSessionRoute(
          target: '合成翻译联系人',
          createController: () => _completion.create(fixture),
          headerBuilder: (_, controller) => TranslationSessionPreviewControls(
            fixture: fixture,
            state: controller.snapshot,
          ),
        ),
      ),
    );
    if (!mounted) return;
    setState(
      () => _result =
          'MOCK · $result\ncreate ${fixture.creates} / merchant ${fixture.merchants} / hangup ${fixture.hangups}\n${fixture.trace.join(' → ')}',
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('翻译共享会话演练')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('MOCK · 仅替换服务端/媒体端口，使用共享协调器、控制器和通话页。不访问网络、麦克风或账号。'),
        ListTile(
          title: const Text('从拨号配置开始完整流程'),
          onTap: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => const TranslationAccessPreviewPage(),
            ),
          ),
        ),
        ListTile(
          title: const Text('LiveKit真实适配双就绪演练'),
          onTap: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => const LiveKitTranslationPreviewPage(),
            ),
          ),
        ),
        for (final entry in const {
          'normal': '正常会话与字幕',
          'fallback': 'LiveKit失败后AppAudio回退',
          'control-failure': '媒体按钮失败',
          'create-failure': '创建失败',
          'hangup-failure': '结束状态待确认',
        }.entries)
          ListTile(
            title: Text(entry.value),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _open(entry.key),
          ),
        if (_result.isNotEmpty) Text(_result),
        ListenableBuilder(
          listenable: _completion,
          builder: (context, _) => Column(
            children: [
              SwitchListTile(
                key: const Key('translation-record-fail-write'),
                title: const Text('MOCK · 本机记录写入失败'),
                value: _completion.store.failWrite,
                onChanged: _completion.failWrite,
              ),
              TranslationRecordSaveStatus(
                state: _completion.saveState,
                onRetry: _completion.recorder.retry,
              ),
              Text('MOCK · 本次演练记录 ${_completion.recentState.records.length} 条'),
              DialRecentList(
                state: _completion.recentState,
                onSelect: (record) => setState(
                  () => _result =
                      'MOCK · ${record.restorablePhone} · ${record.countryIso} · ${record.callerLanguage}，未发起呼叫',
                ),
                onRetry: _completion.recent.load,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
