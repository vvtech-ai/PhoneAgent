import 'package:flutter/material.dart';
import '../../data/preview_livekit_translation.dart';
import '../../data/preview_translation_session.dart';
import '../../domain/translation_call_view.dart';
import '../controller/translation_session_controller.dart';
import 'translation_session_route.dart';

class LiveKitTranslationPreviewPage extends StatefulWidget {
  const LiveKitTranslationPreviewPage({super.key});
  @override
  State<LiveKitTranslationPreviewPage> createState() =>
      _LiveKitTranslationPreviewPageState();
}

class _LiveKitTranslationPreviewPageState
    extends State<LiveKitTranslationPreviewPage> {
  String _result = '';
  Future<void> _open({bool appAudio = false}) async {
    final ports = PreviewLiveKitTranslation(appAudio: appAudio);
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => TranslationSessionRoute(
          target: '合成翻译联系人',
          createController: () => TranslationSessionController(
            backend: ports,
            mediaFactory: ports.factory,
            loadLanguages: ports.languages,
            request: PreviewTranslationSession.request,
          ),
          headerBuilder: (context, controller) {
            final phase = controller.snapshot.phase;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  appAudio
                      ? 'MOCK · AppAudio回退，网络/PCM/权限为合成端口'
                      : 'MOCK · 正式LiveKit适配，房间/权限/后台为合成端口',
                  style: const TextStyle(color: Colors.amber, fontSize: 11),
                ),
                if (appAudio)
                  ListenableBuilder(
                    listenable: ports.pcm,
                    builder: (_, __) => Text(
                      '采集${ports.pcm.started ? '已就绪' : '未启动'} · '
                      '译音${ports.pcm.played.length}帧（模拟消费）',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                if (!controller.snapshot.dialPad)
                  Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      if (phase == TranslationPhase.preflight && !appAudio) ...[
                        TextButton(
                          onPressed: ports.room.roomReady,
                          child: const Text('房间就绪'),
                        ),
                        TextButton(
                          onPressed: () =>
                              ports.room.wire({'event': 'realtime_ready'}),
                          child: const Text('服务就绪'),
                        ),
                      ],
                      if (appAudio) ...[
                        if (phase == TranslationPhase.preflight)
                          TextButton(
                            onPressed: () =>
                                ports.wire({'event': 'app_audio_ready'}),
                            child: const Text('AppAudio就绪'),
                          ),
                        TextButton(
                          onPressed: () =>
                              ports.wire({'event': 'merchant_audio_ready'}),
                          child: const Text('采集就绪'),
                        ),
                        TextButton(
                          onPressed: ports.pcm.pcm,
                          child: const Text('模拟上行'),
                        ),
                        TextButton(
                          onPressed: () => ports.socket.downlink(
                            sequence: ports.pcm.played.length + 1,
                          ),
                          child: const Text('模拟译音'),
                        ),
                      ],
                      if (phase == TranslationPhase.ringing)
                        TextButton(
                          onPressed: () =>
                              ports.wire({'event': 'call_connected'}),
                          child: const Text('模拟接通'),
                        ),
                      if (phase == TranslationPhase.translating)
                        TextButton(
                          onPressed: ports.subtitle,
                          child: const Text('模拟双语'),
                        ),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
    ports.alive = false;
    if (!mounted) return;
    setState(
      () => _result =
          'MOCK · $result\nmerchant ${ports.merchants} / hangup ${ports.hangups}\n'
          '音频占用：${ports.focus.active == null ? '已释放' : '仍占用'}\n${ports.trace.join(' → ')}',
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('翻译共享媒体演练')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('MOCK · 不连接真实房间、不录音、不外呼。分别注入房间/服务就绪，验证同一个生产适配与通话页面。'),
        FilledButton(onPressed: _open, child: const Text('开始双就绪演练')),
        OutlinedButton(
          onPressed: () => _open(appAudio: true),
          child: const Text('开始AppAudio回退演练'),
        ),
        if (_result.isNotEmpty) Text(_result),
      ],
    ),
  );
}
