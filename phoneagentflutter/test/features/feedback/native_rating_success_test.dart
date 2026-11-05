import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/feedback/presentation/widgets/native_task_rating_success.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform success reward and dismissal on short screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final points in [null, 7]) {
        for (final action in ['关闭', '完成']) {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      barrierDismissible: false,
                      barrierColor: const Color(0x66000000),
                      builder: (context) => NativeTaskRatingSuccess(
                        grantedPoints: points,
                        onDismiss: () => Navigator.pop(context),
                      ),
                    ),
                    child: const Text('打开'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('打开'));
          await tester.pumpAndSettle();
          expect(find.text('评价提交成功'), findsOneWidget);
          expect(
            find.text('已获得7积分'),
            points == null ? findsNothing : findsOneWidget,
          );
          expect(
            find.text('积分已发放，本任务不可重复领取。'),
            points == null ? findsNothing : findsOneWidget,
          );
          expect(
            tester.widget<Dialog>(find.byType(Dialog)).alignment,
            Alignment.bottomCenter,
          );
          expect(tester.takeException(), isNull);
          if (action == '完成') {
            await tester.scrollUntilVisible(find.text('完成'), 100);
            await tester.tap(find.text('完成'));
          } else {
            await tester.tap(find.byType(IconButton));
          }
          await tester.pumpAndSettle();
          expect(find.byType(NativeTaskRatingSuccess), findsNothing);
          expect(tester.takeException(), isNull);
        }
      }
    });
  }
}
