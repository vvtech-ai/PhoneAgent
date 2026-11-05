import 'package:flutter/material.dart';
import '../../../../core/design/native_notice.dart';
import '../../domain/translation_call_view.dart';
import '../controller/translation_preview_controller.dart';
import '../widgets/translation_call_controls.dart';
import 'translation_call_page.dart';

Future<String?> openTranslationCallPreview(BuildContext context) async {
  final scenario = await showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    builder: (context) => ListView(
      shrinkWrap: true,
      children: [
        const ListTile(title: Text('MOCK · 不使用输入号码、不发起通话')),
        for (final entry in const {
          'normal': '正常通话与双语转写',
          'preflight': '环境检测失败',
          'hangup': '挂断失败与显式重试',
        }.entries)
          ListTile(
            title: Text(entry.value),
            onTap: () => Navigator.pop(context, entry.key),
          ),
      ],
    ),
  );
  if (!context.mounted || scenario == null) return null;
  return Navigator.push<String>(
    context,
    MaterialPageRoute(
      builder: (_) => TranslationCallPreviewRoute(scenario: scenario),
    ),
  );
}

class TranslationCallPreviewRoute extends StatefulWidget {
  const TranslationCallPreviewRoute({super.key, this.scenario = 'normal'});
  final String scenario;
  @override
  State<TranslationCallPreviewRoute> createState() =>
      _TranslationCallPreviewRouteState();
}

class _TranslationCallPreviewRouteState
    extends State<TranslationCallPreviewRoute> {
  late final TranslationPreviewController _controller;
  late final void Function() _removeListener;
  bool _closing = false;
  String _lastError = '';
  int _segment = 0;
  @override
  void initState() {
    super.initState();
    _controller = TranslationPreviewController(
      failPreflight: widget.scenario == 'preflight',
      failHangup: widget.scenario == 'hangup',
    );
    _removeListener = _controller.addListener((state) {
      if (!mounted) return;
      setState(() {});
      if (!state.terminal && state.error != _lastError) {
        _lastError = state.error;
        if (state.error.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) showNativeNotice(context, state.error);
          });
        }
      }
      if (state.terminal && !_closing) {
        _closing = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.pop(
              context,
              state.phase == TranslationPhase.failed
                  ? state.error
                  : 'MOCK · 翻译通话演练结束，未产生真实记录或费用',
            );
          }
        });
      }
    }, fireImmediately: false);
  }

  @override
  void dispose() {
    _removeListener();
    _controller.dispose();
    super.dispose();
  }

  void _transcript() {
    final id = (++_segment).toString();
    _controller.transcript(
      TranslationTranscript(
        id: id,
        leg: 'local',
        source: '这是第$id条合成对话。',
        translated: 'This is synthetic message $id.',
        sourceLanguage: 'zh',
        translatedLanguage: 'en',
        isFinal: true,
      ),
    );
    _controller.transcript(
      TranslationTranscript(
        id: id,
        leg: 'peer',
        source: 'I understand.',
        translated: '我明白了。',
        sourceLanguage: 'en',
        translatedLanguage: 'zh',
        isFinal: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.snapshot;
    return PopScope(
      canPop: state.terminal,
      child: TranslationCallPage(
        state: state,
        target: '合成翻译联系人',
        controls: TranslationCallControls(
          state: state,
          onMute: _controller.mute,
          onSpeaker: _controller.speaker,
          onPad: _controller.dialPad,
          onDigit: _controller.digit,
          onHangup: _controller.hangup,
        ),
        previewHeader: Column(
          children: [
            const Text(
              'MOCK · 无真实电话、录音、媒体或计费',
              style: TextStyle(color: Colors.amber, fontSize: 11),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, 'MOCK · 已退出演练'),
                  child: const Text('退出演练'),
                ),
                TextButton(
                  onPressed: state.phase == TranslationPhase.translating
                      ? null
                      : _controller.advance,
                  child: const Text('模拟下一阶段'),
                ),
                if (state.phase == TranslationPhase.translating)
                  TextButton(
                    onPressed: _transcript,
                    child: const Text('添加合成双语'),
                  ),
              ],
            ),
            if (state.dtmf.isNotEmpty)
              Text(
                'MOCK DTMF：${state.dtmf}',
                style: const TextStyle(color: Colors.amber, fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }
}
