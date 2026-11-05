import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/domain/invoice.dart';
import 'package:phone_agent/features/commerce/presentation/controller/invoice_controller.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/invoice_sheet.dart';

void main() {
  const capture = String.fromEnvironment('COMMERCE_CAPTURE_DIR');
  setUpAll(() async {
    if (capture.isEmpty) return;
    for (final entry in const {
      'ReferenceText': String.fromEnvironment('UI_PREFLIGHT_FONT'),
      'MaterialIcons': String.fromEnvironment('UI_PREFLIGHT_ICON_FONT'),
    }.entries) {
      final loader = FontLoader(entry.key)
        ..addFont(File(entry.value).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });
  for (final width in [300.0, 320.0, 375.0, 390.0, 430.0]) {
    testWidgets('专票大字键盘操作可达且保留输入 $width', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final draft = InvoiceDraft()
        ..selectTitle('COMPANY')
        ..selectType('SPECIAL');
      draft.set('title', '合成展示企业');
      const captureKey = Key('invoice-keyboard-capture');
      await tester.pumpWidget(
        RepaintBoundary(
          key: captureKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              fontFamily: capture.isEmpty ? null : 'ReferenceText',
            ),
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 844),
                viewInsets: const EdgeInsets.only(bottom: 300),
                textScaler: const TextScaler.linear(2),
              ),
              child: Scaffold(
                backgroundColor: const Color(0xFFF6F7F9),
                resizeToAvoidBottomInset: false,
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 300),
                    child: Material(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      child: InvoiceSheet(
                        cashAmountFen: 3900,
                        state: const InvoiceState(),
                        draft: draft,
                        onClose: () {},
                        onTitle: (_) {},
                        onType: (_) {},
                        onChange: draft.set,
                        onSubmit: () {},
                        onRefresh: () {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final close = find.widgetWithText(FilledButton, '关闭');
      final submit = find.widgetWithText(FilledButton, '提交申请');
      expect(tester.getSize(close).height, tester.getSize(submit).height);
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.text('提交申请')).bottom, lessThan(544));
      final field = find.byKey(const ValueKey('COMPANY-SPECIAL-bankAccount'));
      await tester.scrollUntilVisible(
        field,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(field, '123456789');
      await tester.pump();
      expect(draft.fields['bankAccount'], '123456789');
      expect(draft.fields['title'], '合成展示企业');
      expect(tester.takeException(), isNull);
      if (capture.isNotEmpty) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(captureKey),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '$capture/invoice-keyboard-${width.toInt()}-2x.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }
}
