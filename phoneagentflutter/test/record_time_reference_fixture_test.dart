import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/domain/record_time.dart';
import '../tool/native_ui_reference/flutter_record_time_reference.dart'
    as fixture;

void main() {
  testWidgets('record time formal pages keep distinct dates across return', (
    tester,
  ) async {
    final now = DateTime.now();
    final recent = DateTime(now.year, now.month, now.day - 2, 14, 5);
    final old = DateTime(now.year - 1, 1, 2, 14, 5);
    final recentLabel = recordTimeLabel(recent.toIso8601String());
    final oldLabel = recordTimeLabel(old.toIso8601String());
    fixture.main();
    await tester.pumpAndSettle();
    expect(find.text(recentLabel), findsOneWidget);
    expect(find.text(oldLabel), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('recent-record')));
    await tester.pumpAndSettle();
    expect(find.text('合成近期记录'), findsOneWidget);
    expect(find.text(recentLabel), findsOneWidget);
    expect(find.text(oldLabel), findsNothing);
    await tester.tap(find.byKey(const ValueKey('close-translation')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('previous-year-record')));
    await tester.pumpAndSettle();
    expect(find.text('合成跨年记录'), findsOneWidget);
    expect(find.text(oldLabel), findsOneWidget);
    expect(find.text(recentLabel), findsNothing);
    await tester.tap(find.byKey(const ValueKey('close-translation')));
    await tester.pumpAndSettle();
    expect(find.text(recentLabel), findsOneWidget);
    expect(find.text(oldLabel), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
