import '../../../../core/design/native_confirmation_dialog.dart';
import 'package:flutter/material.dart';
import '../../data/preview_recording_audio.dart';
import '../controller/recording_audio_controller.dart';
import '../controller/translation_history_controller.dart';
import '../widgets/recording_audio_card.dart';
import 'translation_history_page.dart';

class RecordingScenariosPage extends StatelessWidget {
  const RecordingScenariosPage({super.key});
  static const labels = {
    RecordingPreviewScenario.normal: '播放、暂停与保存取消',
    RecordingPreviewScenario.processing: '录音处理中到可播放',
    RecordingPreviewScenario.loadFailure: '加载失败后重新加载',
    RecordingPreviewScenario.playFailure: '播放失败后重新加载',
    RecordingPreviewScenario.saveFailure: '保存失败后重新加载',
  };
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('MOCK · 历史录音场景')),
    body: SafeArea(
      child: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('仅合成字幕和计时，不读取录音、不播放声音、不保存文件。'),
          ),
          for (final item in labels.entries)
            ListTile(
              title: Text(item.value),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => RecordingPreviewPage(scenario: item.key),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class RecordingPreviewPage extends StatefulWidget {
  const RecordingPreviewPage({super.key, required this.scenario});
  final RecordingPreviewScenario scenario;
  @override
  State<RecordingPreviewPage> createState() => _RecordingPreviewPageState();
}

class _RecordingPreviewPageState extends State<RecordingPreviewPage> {
  late final RecordingAudioController _controller;
  late final VoidCallback _removeListener;
  RecordingAudioState _state = const RecordingAudioState();
  @override
  void initState() {
    super.initState();
    _controller = RecordingAudioController(
      repository: PreviewRecordingRepository(widget.scenario),
      player: PreviewRecordingPlayer(widget.scenario),
      exporter: PreviewRecordingExporter(_chooseDestination, widget.scenario),
      isCurrent: () => mounted,
      logicalDurationMillis: PreviewRecordingPlayer.durationMillis,
    );
    _removeListener = _controller.addListener((value) {
      if (mounted) setState(() => _state = value);
    });
    _controller.load();
  }

  Future<bool> _chooseDestination() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => NativeConfirmationDialog(
          title: 'MOCK · 保存录音',
          message: '模拟系统选择保存位置；确认后也不会写入真实文件。',
          dismissLabel: '取消保存',
          confirmLabel: '模拟保存',
        ),
      ) ??
      false;

  @override
  void dispose() {
    _removeListener();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: TranslationHistoryPage.background,
    body: SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'MOCK · 无真实录音 / 声音 / 文件操作',
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: TranslationHistoryPage(
              state: const TranslationHistoryState(
                content:
                    TranslationHistoryContent('合成翻译对象', '', '演练记录', '00:12', [
                      TranslationRow(
                        false,
                        '您好，需要我帮您确认什么？',
                        'Hello, what would you like to confirm?',
                      ),
                      TranslationRow(
                        true,
                        '请确认今天的营业时间。',
                        'Please confirm today’s opening hours.',
                      ),
                      TranslationRow(
                        false,
                        '今天营业到晚上八点。',
                        'We are open until eight this evening.',
                      ),
                    ], true),
              ),
              onClose: () => Navigator.pop(context),
              onRetry: () => _controller.load(),
              recording: RecordingAudioCard(
                state: _state,
                onPrimary: _controller.primary,
                onSave: _controller.save,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
