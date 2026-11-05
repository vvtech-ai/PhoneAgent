import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_receipt.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/receipts/batch_receipt_card.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/receipts/call_receipt_card.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/receipts/preview_call_recording.dart';
import 'package:phone_agent/features/translation_history/data/preview_recording_audio.dart';

void main() {
  Future<void> open(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets(
      'full lazy control at $width supports play pause and save cancel',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 700);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await open(tester, const PreviewCallRecording(compact: false));
        expect(find.byType(CircularProgressIndicator), findsNothing);
        await tester.tap(find.byTooltip('播放录音'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        expect(find.byTooltip('暂停录音'), findsOneWidget);
        await tester.tap(find.byTooltip('暂停录音'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('保存录音'));
        // The underlying saving indicator intentionally spins until a choice.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.text('MOCK · 保存本次录音'), findsOneWidget);
        await tester.tap(find.text('取消保存'));
        await tester.pumpAndSettle();
        expect(find.text('录音已保存'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
  testWidgets('compact only exposes playback and retry, never full card/save', (
    tester,
  ) async {
    await open(
      tester,
      const PreviewCallRecording(
        compact: true,
        scenario: RecordingPreviewScenario.loadFailure,
      ),
    );
    expect(find.byTooltip('保存录音'), findsNothing);
    expect(find.text('通话录音'), findsNothing);
    await tester.tap(find.byTooltip('播放本次电话录音'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('录音加载失败，重新加载'), findsOneWidget);
    await tester.tap(find.byTooltip('录音加载失败，重新加载'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.byTooltip('暂停本次电话录音'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('single insertion uses full slot between transcript and result', (
    tester,
  ) async {
    await open(
      tester,
      CallReceiptCard(
        receipt: CallReceipt(
          attemptId: 'a',
          status: 'COMPLETED',
          transcript: 'AI：合成',
          metadata: const {'callId': 'c', 'agentOutcome': 'SUCCESS'},
        ),
        recordingBuilder: (id, compact) => Text('recording:$id:$compact'),
      ),
    );
    expect(find.text('recording:c:false'), findsOneWidget);
    final y = tester.getTopLeft(find.text('recording:c:false')).dy;
    expect(y, greaterThan(tester.getTopLeft(find.text('通话转写')).dy));
    expect(y, lessThan(tester.getTopLeft(find.text('执行结果')).dy));
  });
  testWidgets('unanswered result with callId never builds recording slot', (
    tester,
  ) async {
    var recordingLookups = 0;
    await open(
      tester,
      CallReceiptCard(
        receipt: CallReceipt(
          attemptId: 'first-attempt',
          status: 'FAILED',
          detail: '通话未接通，请稍后重试',
          metadata: const {
            'callId': 'first-attempt',
            'answered': 'false',
            'durationMillis': '0',
          },
        ),
        recordingBuilder: (_, __) {
          recordingLookups++;
          return const Text('无效录音');
        },
      ),
    );
    expect(recordingLookups, 0);
    expect(find.text('无效录音'), findsNothing);
    expect(find.text('通话未接通，请稍后重试'), findsOneWidget);
  });
  testWidgets(
    'batch inserts compact only for connected item and keeps transcript',
    (tester) async {
      await open(
        tester,
        BatchReceiptCard(
          receipt: BatchReceipt.fromJson({
            'items': [
              for (final id in ['a', 'b'])
                {
                  'itemId': id,
                  'callId': id,
                  'status': 'COMPLETED',
                  'transcript': 'AI：合成$id',
                  'billingSummaries': [
                    {
                      'billingSessionId': id,
                      'connectedDurationMs': id == 'a' ? 1 : 0,
                    },
                  ],
                },
            ],
          }, fallbackId: 'batch'),
          recordingBuilder: (id, compact) => Text('recording:$id:$compact'),
        ),
      );
      expect(find.text('recording:a:true'), findsOneWidget);
      expect(find.text('recording:b:true'), findsNothing);
      expect(find.text('查看通话记录'), findsNWidgets(2));
    },
  );
}
