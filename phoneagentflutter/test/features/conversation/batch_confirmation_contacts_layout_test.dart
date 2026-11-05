import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/batch_confirmation.dart';
import 'package:phone_agent/features/conversation/domain/call_confirmation.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/batch_confirmation_contacts.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('$platform contact audit shared layout at $scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final card = BatchConfirmation(
          snapshotId: 'synthetic-audit',
          version: 1,
          title: '',
          sections: const [],
          recipients: List.generate(
            5,
            (i) => BatchConfirmationRecipient(
              id: '$i',
              name: '合成$i',
              phone: '',
              salutation: '您好$i',
              status: '',
              detail: '',
            ),
          ),
          issues: const [ConfirmationRow('合成问题', '未执行')],
          rules: const [],
          assistantText: '',
          summary: (original: 6, callable: 5, skipped: 1),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: SingleChildScrollView(
                    child: BatchConfirmationContacts(confirmation: card),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        Text text(String value) => tester.widget<Text>(find.text(value));
        for (final entry in {
          '6': 0xFF172033,
          '5': 0xFF187A3A,
          '1': 0xFF8A4F00,
        }.entries) {
          expect(text(entry.key).style!.color, Color(entry.value));
        }
        final metric = find
            .ancestor(of: find.text('6'), matching: find.byType(Container))
            .first;
        expect(
          tester.getSize(metric).height,
          closeTo(scale == 1 ? 52 : 110, .01),
        );
        for (final label in ['原始联系人', '可拨打', '暂不执行']) {
          expect(text(label).style!.color, const Color(0xFF596579));
        }
        final salutation = find.text('您好0');
        expect(text('您好0').style!.fontWeight, FontWeight.w700);
        final recipient = find
            .ancestor(of: salutation, matching: find.byType(Container))
            .first;
        final bounds = tester.getRect(recipient);
        expect(
          bounds.right - tester.getRect(salutation).right,
          closeTo(10, .01),
        );
        expect(
          tester.getRect(find.text('合成0')).left - bounds.left,
          closeTo(10, .01),
        );
        final toggle = find.byKey(
          const ValueKey('batch-confirmation-toggle-contacts'),
        );
        expect(tester.getSize(toggle).height, greaterThanOrEqualTo(48));
        final button = tester.widget<TextButton>(toggle);
        expect(button.style!.textStyle!.resolve({})!.fontSize, 12);
        expect(
          button.style!.textStyle!.resolve({})!.fontWeight,
          FontWeight.w700,
        );
        expect(
          tester.getRect(find.text('查看全部 5 位联系人')).left,
          closeTo(bounds.left, .01),
        );
        expect(find.text('合成4'), findsNothing);
        await tester.ensureVisible(toggle);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(find.text('合成4'), findsOneWidget);
        await tester.ensureVisible(toggle);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(find.text('合成4'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
