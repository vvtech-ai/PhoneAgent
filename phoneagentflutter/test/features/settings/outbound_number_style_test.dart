import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/settings/presentation/controller/outbound_number_controller.dart';
import 'package:phone_agent/features/settings/presentation/pages/outbound_number_page.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('$platform outbound state styles at $scale', (tester) async {
        tester.view.physicalSize = const Size(320, 480);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var edits = 0, writes = 0;
        Future<void> show(OutboundNumberState state) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(
                platform: platform,
                colorSchemeSeed: Colors.purple,
              ),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: OutboundNumberPage(
                  state: state,
                  onEdit: (_) => edits++,
                  onLoad: () async => false,
                  onSave: () async {
                    writes++;
                    return false;
                  },
                  onDelete: () async {
                    writes++;
                    return false;
                  },
                ),
              ),
            ),
          );
          await tester.pump();
        }

        await show(const OutboundNumberState(draft: '13800000000'));
        await tester.tap(find.byType(TextField));
        await tester.pump();
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .focusNode
              .hasFocus,
          true,
        );
        final input = tester.widget<TextField>(find.byType(TextField));
        for (final border in [
          input.decoration!.enabledBorder,
          input.decoration!.focusedBorder,
          input.decoration!.disabledBorder,
        ]) {
          expect(border, isA<OutlineInputBorder>());
          expect(
            border!.borderSide,
            const BorderSide(color: Color(0x143C3C43)),
          );
          expect(
            (border as OutlineInputBorder).borderRadius,
            BorderRadius.circular(18),
          );
        }
        expect(input.style!.height, 18 / 15);
        expect(input.style!.letterSpacing, 0);
        expect(
          tester.getSize(find.byType(TextField)).height,
          greaterThanOrEqualTo(48),
        );
        await tester.enterText(find.byType(TextField), '13900000000');
        expect(edits, 1);

        await show(
          const OutboundNumberState(operation: OutboundOperation.loading),
        );
        expect(tester.widget<TextField>(find.byType(TextField)).enabled, false);
        final loading = tester.widget<Text>(find.text('正在读取当前固定外呼号码...'));
        expect(loading.style!.color, const Color(0xFF6E6E73));
        await tester.ensureVisible(find.text('保存'));
        await tester.tap(find.text('保存'));
        await tester.pump();
        expect(writes, 0);

        await show(const OutboundNumberState(error: '合成读取失败'));
        final error = tester.widget<Text>(find.text('合成读取失败'));
        expect(error.style!.color, const Color(0xFFE14D46));
        expect(error.style!.fontSize, 12);
        expect(error.style!.height, 14 / 12);
        expect(find.text('重新读取'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
