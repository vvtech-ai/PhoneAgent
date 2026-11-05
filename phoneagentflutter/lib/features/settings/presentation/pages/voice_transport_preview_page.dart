import 'package:flutter/material.dart';
import '../controller/voice_transport_preview_controller.dart';

class VoiceTransportPreviewPage extends StatefulWidget {
  const VoiceTransportPreviewPage({super.key});
  @override
  State<VoiceTransportPreviewPage> createState() =>
      _VoiceTransportPreviewPageState();
}

class _VoiceTransportPreviewPageState extends State<VoiceTransportPreviewPage> {
  final controller = VoiceTransportPreviewController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('语音网关链路演练')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: controller,
        builder: (_, __) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'MOCK · 共用 ASR/TTS 编排、PCM 队列及音频占用；采集源、输出设备和 socket 均为内存模拟。不录音、不播放、不连接真实服务。',
            ),
            Text('ASR：${controller.asrStatus}'),
            FilledButton(
              onPressed: controller.startAsr,
              child: const Text('新建 ASR 连接'),
            ),
            OutlinedButton(
              onPressed: controller.ready,
              child: const Text('模拟网关 ready'),
            ),
            OutlinedButton(
              onPressed: controller.sendPcm,
              child: const Text('发送 640 字节合成 PCM'),
            ),
            Text(
              'PCM：${controller.pcmAccepted ? '已发送' : '未发送'} · 累计 ${controller.asrSocket?.sentPcmBytes ?? 0} 字节',
            ),
            OutlinedButton(
              onPressed: controller.release,
              child: const Text('模拟松手'),
            ),
            OutlinedButton(
              onPressed: controller.finalText,
              child: const Text('模拟最终文本'),
            ),
            Text('文本：${controller.text}'),
            OutlinedButton(
              onPressed: controller.cancel,
              child: const Text('取消 ASR'),
            ),
            Text('ASR 控制：${controller.asrSocket?.commands.join(' → ') ?? ''}'),
            const Divider(),
            FilledButton(
              onPressed: controller.synthesize,
              child: const Text('演练 TTS 预缓冲与尾块'),
            ),
            Text('TTS：${controller.ttsStatus}'),
            Text('输出块：${controller.chunks.join('、')} 字节'),
            Text('设备：${controller.outputStatus}'),
            Text(
              '待播：${controller.pendingOutputBytes} 字节 · 音频${controller.audioOccupied ? '占用中' : '已释放'}',
            ),
            OutlinedButton(
              onPressed: controller.consumeOutput,
              child: const Text('模拟设备实际播完'),
            ),
            OutlinedButton(
              onPressed: controller.stopOutput,
              child: const Text('取消 TTS 播放'),
            ),
            OutlinedButton(
              onPressed: controller.failOutput,
              child: const Text('模拟设备播放失败'),
            ),
            const Text(
              '预期：ready 前不能发送 PCM；松手后一次 final；取消不继续旧轮。TTS 输出 24000 + 2 字节，complete 不是实际播放完成。',
            ),
          ],
        ),
      ),
    ),
  );
}
