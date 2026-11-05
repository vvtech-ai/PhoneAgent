import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/presentation/controller/call_presentation.dart';
import 'package:phone_agent/features/calls/presentation/controller/call_preview_controller.dart';
import 'package:phone_agent/features/calls/presentation/pages/call_preview_route.dart';
import 'package:phone_agent/features/calls/presentation/widgets/call_controls.dart';
import 'package:phone_agent/features/conversation/presentation/controller/preview_call_recording_session.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_conversation_close.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/receipts/call_recording_route.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform close has no tooltip and keeps its tap action', (
      t,
    ) async {
      var closes = 0;
      await t.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Scaffold(
            body: NativeConversationClose(onClose: () => closes++),
          ),
        ),
      );
      expect(find.bySemanticsLabel('关闭任务对话'), findsOneWidget);
      await t.longPress(find.byKey(const ValueKey('close-conversation')));
      await t.pump(const Duration(seconds: 1));
      expect(find.byType(Tooltip), findsNothing);
      final beforeTap = closes;
      await t.tap(find.byKey(const ValueKey('close-conversation')));
      expect(closes, beforeTap + 1);
    });

    testWidgets('$platform recording save is a transient notice', (t) async {
      final manager = createPreviewCallRecordings(() async => true);
      await t.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Scaffold(
            body: CallRecordingRoute(
              manager: manager,
              callId: 'synthetic',
              compact: false,
            ),
          ),
        ),
      );
      await t.pump();
      await t.tap(find.byTooltip('保存录音'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.pump();
      expect(find.text('录音已保存'), findsOneWidget);
      expect(find.byKey(const ValueKey('nativeNoticeSurface')), findsOneWidget);
      await t.pump(const Duration(seconds: 3));
      await t.pump(const Duration(milliseconds: 250));
      expect(find.text('录音已保存'), findsNothing);
      await t.pump();
      expect(find.byKey(const ValueKey('nativeNoticeSurface')), findsNothing);
      await t.pumpWidget(const SizedBox());
      manager.dispose();
      await t.pumpAndSettle();
    });
  }

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('dark source sheet at $width cancels without switching', (
      t,
    ) async {
      t.view.physicalSize = Size(width, 700);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      CallAudioSource? result;
      var dismissed = false;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showCallAudioSources(
                    context,
                    const CallMonitorView(),
                  );
                  dismissed = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      expect(find.text('发声源'), findsOneWidget);
      expect(find.text('选择监听声音的播放设备'), findsOneWidget);
      expect(
        t
            .widget<Material>(
              find
                  .descendant(
                    of: find.byType(BottomSheet),
                    matching: find.byType(Material),
                  )
                  .first,
            )
            .color,
        const Color(0xFF191D25),
      );
      expect(find.byType(Radio<CallAudioSource>), findsNWidgets(2));
      await t.tap(find.text('取消'));
      await t.pumpAndSettle();
      expect(dismissed, isTrue);
      expect(result, isNull);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('outbound page has controls without additional monitor status', (
    t,
  ) async {
    await t.pumpWidget(const MaterialApp(home: CallPreviewScenariosPage()));
    await t.tap(
      find.text(
        CallPreviewScenariosPage.labels[CallPreviewScenario.connected]!,
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('监听'), findsOneWidget);
    expect(find.text('监听已关闭'), findsNothing);
    await t.tap(find.byKey(const ValueKey('call-开始监听')));
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();
    expect(find.text('正在监听'), findsNothing);
    expect(find.byKey(const ValueKey('call-停止监听')), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  });
}
