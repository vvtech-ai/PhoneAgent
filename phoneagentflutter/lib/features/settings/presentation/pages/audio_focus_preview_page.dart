import 'package:flutter/material.dart';
import '../../../translation_history/presentation/widgets/recording_audio_card.dart';
import '../controller/audio_focus_preview_controller.dart';

class AudioFocusPreviewPage extends StatefulWidget {
  const AudioFocusPreviewPage({super.key});
  @override
  State<AudioFocusPreviewPage> createState() => _AudioFocusPreviewPageState();
}

class _AudioFocusPreviewPageState extends State<AudioFocusPreviewPage> {
  final controller = AudioFocusPreviewController();
  @override
  void initState() {
    super.initState();
    controller.initialize();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('跨模块音频演练')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('MOCK · 仅计时和内存事件，无声音、录音、文件、权限或账号请求。共用正式音频管理器和播放适配器。'),
            const SizedBox(height: 12),
            const Text('普通回执录音'),
            RecordingAudioCard(
              state: controller.ordinaryState,
              onPrimary: controller.ordinary.primary,
              onSave: controller.ordinary.save,
            ),
            const Text('翻译历史录音'),
            RecordingAudioCard(
              state: controller.translationState,
              onPrimary: controller.translation.primary,
              onSave: controller.translation.save,
            ),
            FilledButton(
              onPressed: controller.clonePlaying
                  ? null
                  : controller.previewClone,
              child: Text(
                controller.clonePlaying ? '克隆试听中（MOCK）' : '开始克隆试听（MOCK）',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('模拟普通录音停止失败'),
              value: controller.ordinaryPort.failPause,
              onChanged: controller.failPause,
            ),
            OutlinedButton(
              onPressed: controller.stopAll,
              child: const Text('停止全部合成播放'),
            ),
            Text(
              '普通：${controller.ordinaryState.phase.name} · 翻译：${controller.translationState.phase.name}',
            ),
            Text(controller.message),
            const Divider(),
            Text('SDK：${controller.captureStatus}'),
            FilledButton(
              onPressed: controller.capturing ? null : controller.beginCapture,
              child: const Text('开始合成 SDK 采集'),
            ),
            OutlinedButton(
              onPressed: controller.capturing && !controller.cancellingCapture
                  ? controller.cancelCapture
                  : null,
              child: const Text('取消采集（暂不释放）'),
            ),
            OutlinedButton(
              onPressed: controller.capturing ? controller.finishCapture : null,
              child: const Text('模拟 SDK 回调并释放'),
            ),
            const Text('采集期间禁止试听抢占。取消只结束业务；模拟 SDK 释放后才可重新播放。此处没有调用真实 SDK。'),
            const Text('切换必须先停止旧播放；失败时新播放器不能启动。解除失败后可重试。'),
          ],
        ),
      ),
    ),
  );
}
