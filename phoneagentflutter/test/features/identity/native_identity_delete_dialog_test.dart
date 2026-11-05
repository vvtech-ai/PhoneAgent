import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/identity/presentation/widgets/identity_widgets.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform identity delete dialog cancels and confirms safely',
      (tester) async {
        tester.view.physicalSize = const Size(320, 480);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        for (final scale in [1.0, 2.0]) {
          for (final confirm in [false, true]) {
            bool? result;
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(platform: platform),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () async {
                        result = await showDialog<bool>(
                          context: context,
                          builder: (_) => const IdentityDeleteDialog(),
                        );
                      },
                      child: const Text('打开'),
                    ),
                  ),
                ),
              ),
            );
            await tester.tap(find.text('打开'));
            await tester.pumpAndSettle();
            final message = find.text(
              '删除后将清除身份信息、全部模型的当前及候选克隆音色，以及本地认证录音。该操作不可恢复，是否继续？',
            );
            expect(message, findsOneWidget);
            final style = tester.widget<Text>(message).style!;
            expect(style.fontSize, 13);
            expect(style.height! * style.fontSize!, 18);
            expect(
              (tester.widget<Dialog>(find.byType(Dialog)).shape!
                      as RoundedRectangleBorder)
                  .borderRadius,
              BorderRadius.circular(22),
            );
            final button = find.widgetWithText(
              TextButton,
              confirm ? '删除身份' : '取消',
            );
            await tester.scrollUntilVisible(button, 100);
            await tester.tap(button);
            await tester.pumpAndSettle();
            expect(result, confirm);
            expect(find.byType(IdentityDeleteDialog), findsNothing);
            expect(tester.takeException(), isNull);
          }
        }
      },
    );
  }
}
