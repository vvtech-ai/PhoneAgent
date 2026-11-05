import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/trusted_caller/presentation/widgets/trusted_caller_home_guide.dart';

void main() {
  testWidgets('native reminder has no blank title space and readable body', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var confirmed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrustedCallerHomeReminder(onConfirm: () => confirmed++),
        ),
      ),
    );
    final body = find.text('你可以稍后在设置中开启可信通信被叫。');
    final text = tester.widget<Text>(body);
    expect(text.style?.fontSize, 14);
    expect(text.style?.color, const Color(0xFF111111));
    final surface = find
        .descendant(of: find.byType(Dialog), matching: find.byType(Material))
        .first;
    final bounds = tester.getRect(surface);
    expect(bounds.width, 280);
    expect(tester.getRect(body).top - bounds.top, closeTo(20, 1));
    expect(
      tester
          .getSize(find.byKey(const Key('trusted-home-reminder-confirm')))
          .height,
      52,
    );
    await tester.tap(find.text('知道了'));
    expect(confirmed, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small screen and enlarged text keep reminder reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(240, 320);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    var confirmed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrustedCallerHomeReminder(onConfirm: () => confirmed = true),
        ),
      ),
    );
    final action = find.byKey(const Key('trusted-home-reminder-confirm'));
    await tester.ensureVisible(action);
    await tester.tap(action);
    expect(confirmed, isTrue);
    expect(tester.takeException(), isNull);
  });
}
