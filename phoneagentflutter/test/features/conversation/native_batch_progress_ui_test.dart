import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_receipt.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/receipts/batch_receipt_card.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/receipts/native_batch_receipt_shell.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final running in [true, false]) {
      testWidgets(
        'batch progress small large-text $platform running=$running',
        (tester) async {
          tester.view.physicalSize = const Size(320, 390);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final receipt = BatchReceipt.fromJson({
            'status': running ? 'RUNNING' : 'COMPLETED',
            'totalCount': 2,
            'items': [
              {'itemId': 'a', 'targetName': '合成甲', 'status': 'SUCCESS'},
              {
                'itemId': 'b',
                'targetName': '合成乙',
                'status': running ? 'RUNNING' : 'FAILED',
              },
            ],
          }, fallbackId: 'ui');
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: BatchReceiptCard(receipt: receipt),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.byType(NativeBatchReceiptShell),
            findsNWidgets(running ? 1 : 2),
          );
          final progress = tester.widget<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          );
          expect(progress.value, running ? .5 : 1);
          expect(progress.semanticsValue, running ? '1/2' : '2/2');
          expect(receipt.successCount, 1);
          final shell = tester.getRect(
            find
                .descendant(
                  of: find.byType(NativeBatchReceiptShell).first,
                  matching: find.byType(DecoratedBox),
                )
                .first,
          );
          final status = tester.getRect(
            find.text('${receipt.completedCount}/2').first,
          );
          expect(status.right, closeTo(shell.right - 14, .01));
          final counts = tester.getRect(
            find.text('${receipt.completedCount}/2 已产生结果'),
          );
          expect(counts.right, closeTo(shell.right - 14, .01));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'zero count keeps server status and reduced motion jumps to target',
    (tester) async {
      Future<void> pump(BatchReceipt receipt) async {
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: Scaffold(body: BatchReceiptCard(receipt: receipt)),
          ),
        );
        await tester.pump();
      }

      await pump(
        BatchReceipt.fromJson({'status': 'RUNNING'}, fallbackId: 'zero'),
      );
      expect(find.text('RUNNING'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        0,
      );
      await pump(
        BatchReceipt.fromJson({
          'status': 'RUNNING',
          'totalCount': 2,
          'items': [
            {'status': 'FAILED'},
          ],
        }, fallbackId: 'one'),
      );
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        .5,
      );
      expect(find.text('1/2 已产生结果'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('queued recipients stay visible in the running call card', (
    tester,
  ) async {
    final receipt = BatchReceipt.fromJson({
      'status': 'RUNNING',
      'totalCount': 3,
      'items': [
        {'itemId': 'a', 'targetName': '已拨联系人', 'status': 'CALLING'},
        {
          'itemId': 'c',
          'targetName': '等待联系人',
          'status': 'WAITING_CALL',
          'headline': '等待呼叫中',
          'detail': '等待联系人等待呼叫中，当前最多同时呼叫 2 路',
        },
      ],
    }, fallbackId: 'queued');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BatchReceiptCard(receipt: receipt)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('等待联系人'), findsOneWidget);
    expect(find.text('等待呼叫中'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'initial snapshot is immediate and later progress transitions for 300ms',
    (tester) async {
      Future<void> show(int completed) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BatchReceiptCard(
                receipt: BatchReceipt.fromJson({
                  'status': 'RUNNING',
                  'totalCount': 2,
                  'items': [
                    for (var i = 0; i < completed; i++) {'status': 'FAILED'},
                  ],
                }, fallbackId: 'same'),
              ),
            ),
          ),
        );
      }

      double value() => tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value!;
      await show(0);
      expect(value(), 0);
      await show(1);
      expect(value(), 0);
      await tester.pump(const Duration(milliseconds: 150));
      expect(value(), greaterThan(0));
      expect(value(), lessThan(.5));
      await tester.pump(const Duration(milliseconds: 150));
      expect(value(), .5);
    },
  );
}
