import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/mobile_preview.dart';

void main() {
  for (final width in [360.0, 390.0, 430.0, 1280.0]) {
    testWidgets('mobile viewport and overlays at $width', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      double? logicalWidth;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MobilePreview(child: child!),
          home: Builder(
            builder: (context) {
              logicalWidth = MediaQuery.sizeOf(context).width;
              return Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const AlertDialog(content: Text('overlay')),
                  ),
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      );
      final expected = width > 430 ? 430.0 : width;
      expect(logicalWidth, expected);
      expect(tester.getSize(find.byType(Scaffold)).width, expected);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byType(AlertDialog));
      expect(rect.left, greaterThanOrEqualTo((width - expected) / 2));
      expect(rect.right, lessThanOrEqualTo((width + expected) / 2));
      expect(tester.takeException(), isNull);
    });
  }
}
