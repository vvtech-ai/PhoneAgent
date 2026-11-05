import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/settings/presentation/pages/voice_transport_preview_page.dart';
import 'package:phone_agent/features/settings/presentation/controller/voice_transport_preview_controller.dart';

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('gateway interaction without native media at $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(home: VoiceTransportPreviewPage()),
      );
      Future<void> tap(String label) async {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }

      await tap('新建 ASR 连接');
      await tap('发送 640 字节合成 PCM');
      expect(find.text('PCM：未发送 · 累计 0 字节'), findsOneWidget);
      await tap('模拟网关 ready');
      await tap('发送 640 字节合成 PCM');
      expect(find.text('PCM：已发送 · 累计 640 字节'), findsOneWidget);
      await tap('模拟松手');
      await tap('模拟最终文本');
      expect(find.text('文本：合成最终文本'), findsOneWidget);
      await tap('取消 ASR');
      expect(
        find.text('ASR 控制：start_capture → stop_capture → finish'),
        findsOneWidget,
      );
      await tap('演练 TTS 预缓冲与尾块');
      expect(find.text('输出块：24000、2 字节'), findsOneWidget);
      expect(find.text('TTS：合成完成，不代表播放排空'), findsOneWidget);
      expect(find.text('设备：等待设备播完'), findsOneWidget);
      expect(find.text('待播：42242 字节 · 音频占用中'), findsOneWidget);
      await tap('模拟设备实际播完');
      expect(find.text('设备：已播完并释放'), findsOneWidget);
      expect(find.text('待播：0 字节 · 音频已释放'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  test(
    'preview output interruption and failure use the shared production pipeline',
    () async {
      final controller = VoiceTransportPreviewController();
      await controller.synthesize();
      await Future<void>.delayed(Duration.zero);
      expect(controller.outputStatus, '等待设备播完');
      await controller.stopOutput();
      expect(controller.outputStatus, '已取消');
      expect(controller.audioOccupied, false);
      await controller.synthesize();
      await Future<void>.delayed(Duration.zero);
      controller.failOutput();
      await Future<void>.delayed(Duration.zero);
      expect(controller.outputStatus, '播放失败');
      expect(controller.audioOccupied, false);
      controller.dispose();
    },
  );
  test(
    'concurrent preview start requests leave only latest connection',
    () async {
      final controller = VoiceTransportPreviewController();
      await controller.startAsr();
      final old = controller.asrSocket!;
      await Future.wait([controller.startAsr(), controller.startAsr()]);
      expect(old.closed, isTrue);
      expect(controller.asrSocket, isNot(same(old)));
      controller.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(controller.asrSocket!.closed, isTrue);
    },
  );
}
