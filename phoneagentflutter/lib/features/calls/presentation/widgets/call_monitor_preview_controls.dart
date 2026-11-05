import 'package:flutter/material.dart';
import '../../data/preview_call_monitor.dart';

class CallMonitorPreviewControls extends StatelessWidget {
  const CallMonitorPreviewControls({super.key, required this.ports});
  final PreviewCallMonitor ports;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: ports,
    builder: (context, _) => Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            'MOCK监听：票据${ports.tickets} / 播放${ports.receivedBytes}字节',
            style: const TextStyle(fontSize: 11),
          ),
        ),
        PopupMenuButton<String>(
          tooltip: '监听演练',
          onSelected: (value) {
            switch (value) {
              case 'pcm':
                ports.pcm();
              case 'disconnect':
                ports.disconnect();
              case 'failure':
                ports.toggleFailure();
              case 'bluetooth':
                ports.toggleBluetooth();
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'pcm', child: Text('注入合成PCM')),
            const PopupMenuItem(value: 'disconnect', child: Text('断开合成监听')),
            PopupMenuItem(
              value: 'failure',
              child: Text(ports.failConnections ? '恢复票据服务' : '模拟票据持续失败'),
            ),
            PopupMenuItem(
              value: 'bluetooth',
              child: Text(ports.bluetooth ? '移除合成蓝牙' : '接入合成蓝牙'),
            ),
          ],
          child: const Padding(padding: EdgeInsets.all(8), child: Text('监听演练')),
        ),
      ],
    ),
  );
}
