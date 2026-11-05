import '../../support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/presentation/pages/permission_preview_page.dart';

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets(
      'permission flow at $width allows, denies, continues and returns',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const PermissionPreviewPage(),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpUntilUiSettled();
        await tester.tap(find.byKey(const ValueKey('toggle-text')));
        await tester.pumpUntilUiSettled();
        Future<void> send(String text) async {
          await tester.enterText(find.byType(TextField), text);
          await tester.pump();
          await tester.tap(find.byKey(const ValueKey('send-text')));
          await tester.pumpUntilUiSettled();
        }

        await send('允许演练');
        expect(find.textContaining('已收到权限结果 OK'), findsOneWidget);
        await tester.tap(find.text('模拟允许'));
        await tester.pumpUntilUiSettled();
        await tester.tap(find.text('模拟拒绝').last);
        await tester.pumpUntilUiSettled();
        await send('拒绝后仍可继续');
        expect(find.textContaining('已收到权限结果 DENIED'), findsOneWidget);
        await tester.tap(find.text('模拟拒绝'));
        await tester.pumpUntilUiSettled();
        await tester.tap(find.text('模拟不可用/需设置').last);
        await tester.pumpUntilUiSettled();
        await send('不可用演练');
        expect(
          find.textContaining('已收到权限结果 SETTINGS_REQUIRED'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('close-conversation')));
        await tester.pumpUntilUiSettled();
        expect(find.text('open'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
