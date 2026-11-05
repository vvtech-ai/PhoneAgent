import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/native_dialog_body.dart';
import 'package:phone_agent/core/design/native_business_dialog.dart';
import 'package:phone_agent/features/settings/presentation/widgets/account_entry_confirmation_dialog.dart';

void main() {
  for (final sample in [
    ('短提示', 220.0, 1.0, TextAlign.center),
    ('第一行\n第二行', 220.0, 1.0, TextAlign.left),
    ('注销账号后全部信息无法找回请谨慎操作', 100.0, 1.0, TextAlign.left),
    ('确认是否继续操作', 180.0, 1.0, TextAlign.center),
    ('确认是否继续操作', 180.0, 2.0, TextAlign.left),
  ]) {
    testWidgets('actual text layout ${sample.$2}/${sample.$3} ${sample.$1}', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(sample.$3)),
            child: Center(
              child: SizedBox(
                width: sample.$2,
                child: NativeDialogBody(
                  sample.$1,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
        ),
      );
      final text = find.descendant(
        of: find.byType(NativeDialogBody),
        matching: find.byType(Text),
      );
      expect(tester.widget<Text>(text).textAlign, sample.$4);
      final rich = find.descendant(of: text, matching: find.byType(RichText));
      final paragraph = tester.renderObject<RenderParagraph>(rich);
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: sample.$1.length),
      );
      if (sample.$4 == TextAlign.center) {
        expect(boxes, hasLength(1));
        expect(boxes.first.left, greaterThan(0));
      } else {
        expect(boxes.map((b) => b.top).toSet().length, greaterThan(1));
        expect(boxes.first.left, closeTo(0, 0.01));
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('resizing recalculates alignment in the same mounted body', (
    tester,
  ) async {
    var width = 200.0;
    late StateSetter resize;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (_, setState) {
            resize = setState;
            return Center(
              child: SizedBox(
                width: width,
                child: const NativeDialogBody(
                  '确认是否继续操作',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            );
          },
        ),
      ),
    );
    Text rendered() => tester.widget<Text>(find.text('确认是否继续操作'));
    expect(rendered().textAlign, TextAlign.center);
    resize(() => width = 80);
    await tester.pump();
    expect(rendered().textAlign, TextAlign.left);
    resize(() => width = 200);
    await tester.pump();
    expect(rendered().textAlign, TextAlign.center);
  });
  for (final danger in [false, true]) {
    testWidgets(
      'common and danger dialog retain centered title, adapt body $danger',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: NativeBusinessDialog(
              title: '标题',
              message: '正文第一行\n正文第二行',
              danger: danger,
              kind: NativeDialogKind.confirmation,
              confirmLabel: '确定',
              onConfirm: () {},
            ),
          ),
        );
        expect(
          tester.widget<Text>(find.text('标题')).textAlign,
          TextAlign.center,
        );
        expect(
          tester.widget<Text>(find.text('正文第一行\n正文第二行')).textAlign,
          TextAlign.left,
        );
      },
    );
  }
  testWidgets(
    'entry title is centered, body left; phone and input stay unchanged',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    showAccountEntryConfirmation(context, '13800000000'),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text('确认注销账号？')).textAlign,
        TextAlign.center,
      );
      expect(
        tester.widget<Text>(find.textContaining('注销账号后，全部信息')).textAlign,
        TextAlign.left,
      );
      expect(
        tester
            .widget<RichText>(find.textContaining('当前账号', findRichText: true))
            .textAlign,
        TextAlign.center,
      );
      expect(
        find.byKey(const Key('account-confirmation-input')),
        findsOneWidget,
      );
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
    },
  );
}
