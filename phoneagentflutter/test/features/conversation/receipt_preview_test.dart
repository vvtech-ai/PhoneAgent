import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/settings/presentation/pages/developer_preview_page.dart';
import 'package:phone_agent/features/conversation/presentation/pages/receipt_preview_page.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(320, 480)]) {
    testWidgets('developer entry, receipt updates, input and back at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: DeveloperPreviewPage()));
      await tester.scrollUntilVisible(find.text('统一对话回执演练'), 180);
      await tester.ensureVisible(find.text('统一对话回执演练'));
      await tester.tap(find.text('统一对话回执演练'));
      await tester.pumpAndSettle();
      expect(find.byType(ReceiptPreviewPage), findsOneWidget);
      final toggle = find.byKey(const ValueKey('receipt-transcript:c'));
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.text('这是合成丙的离线记录。'), findsOneWidget);
      await tester.tap(find.text('模拟收到批量终态'));
      await tester.pumpAndSettle();
      expect(find.text('这是合成丙的离线记录。'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('toggle-text')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('conversation-input')),
        '只在离线演练发送',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('send-text')));
      await tester.pumpAndSettle();
      // Expansion leaves the reverse timeline away from its newest edge.
      tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byKey(const ValueKey('conversation-timeline')),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('只在离线演练发送'), findsOneWidget);
      expect(find.text('MOCK · 文字只保留在演练页面，没有网络请求'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('close-conversation')));
      await tester.pumpAndSettle();
      expect(find.byType(ReceiptPreviewPage), findsNothing);
      expect(find.text('开发者功能演练'), findsOneWidget);
      await tester.tap(find.text('统一对话回执演练'));
      await tester.pumpAndSettle();
      expect(find.text('只在离线演练发送'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ReceiptPreviewPage), findsNothing);
    });
  }
}
