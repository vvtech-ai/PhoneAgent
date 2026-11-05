import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/settings/presentation/pages/outbound_number_page.dart';
import '../tool/native_ui_reference/flutter_outbound_reference.dart' as fixture;

void main() {
  testWidgets(
    'isolated outbound fixture renders production page and returns locally',
    (tester) async {
      fixture.main();
      await tester.pumpAndSettle();
      expect(find.byType(OutboundNumberPage), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '13800000000',
      );
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.byType(OutboundNumberPage), findsOneWidget);
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(find.byType(OutboundNumberPage), findsNothing);
      expect(find.text('合成外呼配置已返回'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
