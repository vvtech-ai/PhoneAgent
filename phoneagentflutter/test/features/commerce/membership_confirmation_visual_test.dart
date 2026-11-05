import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/data/commerce_dto.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/membership_confirmation_sheet.dart';
import 'membership_contract_v2_test.dart' show fixture;

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
    await Directory(capture).create(recursive: true);
  });
  for (final type in ['new', 'upgrade', 'renew', 'lower_queued', 'small']) {
    testWidgets('$type centered dialog geometry and readable actions', (
      tester,
    ) async {
      final small = type == 'small';
      final size = small ? const Size(320, 568) : const Size(390, 844);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final data = fixture('quote-${small ? 'lower_queued' : type}');
      if (small) {
        final preview = Map<String, Object?>.from(
          data['membershipPreview'] as Map,
        );
        final item = Map<String, Object?>.from(
          (preview['precedingEntitlements'] as List).first as Map,
        );
        preview['precedingEntitlements'] = List.generate(
          20,
          (i) => {...item, 'position': i + 1},
        );
        data['membershipPreview'] = preview;
      }
      final quote = CommerceDto.quote({
        ...data,
        'quoteId': 'q',
        'productId': 'm',
        'configVersionId': 1,
        'cashAmountFen': 4000,
        'currency': 'CNY',
        'expiresAt': '2099-01-01T00:00:00+08:00',
      });
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              fontFamily: capture.isEmpty ? null : 'ReferenceText',
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(small ? 2 : 1)),
              child: child!,
            ),
            home: Scaffold(
              backgroundColor: const Color(0xFFF3F5F8),
              body: Builder(
                builder: (context) => Center(
                  child: TextButton(
                    onPressed: () => showDialog<bool>(
                      context: context,
                      builder: (dialog) => MembershipConfirmationSheet(
                        agreementAccepted: true,
                        quote: quote,
                        productName: '初级会员包月',
                        displayPrice: '¥40.00',
                        apple: false,
                        onConfirm: () => Navigator.pop(dialog, true),
                      ),
                    ),
                    child: const Text('会员权益'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('会员权益'));
      await tester.pumpAndSettle();
      final rect = tester.getRect(
        find.byKey(const ValueKey('membership-confirmation-card')),
      );
      expect(rect.left, greaterThanOrEqualTo(16));
      expect(rect.right, lessThanOrEqualTo(size.width - 16));
      expect(rect.top, greaterThanOrEqualTo(16));
      expect(rect.bottom, lessThanOrEqualTo(size.height - 16));
      final price = find.byKey(const ValueKey('membership-confirmation-price'));
      final priceRect = tester.getRect(price);
      final paragraph = tester.renderObject<RenderParagraph>(price);
      final boxes = paragraph.getBoxesForSelection(
        const TextSelection(baseOffset: 0, extentOffset: 6),
      );
      expect(boxes.map((box) => box.top.round()).toSet(), hasLength(1));
      expect(priceRect.right, lessThanOrEqualTo(rect.right - 22));
      if (small) {
        expect(
          priceRect.top,
          greaterThan(tester.getRect(find.text('本次应付')).bottom),
        );
      }
      expect(tester.takeException(), isNull);
      if (capture.isNotEmpty) {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            '$capture/confirmation-$type.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.ensureVisible(find.text('支付 ¥40.00'));
      await tester.pumpAndSettle();
      expect(find.text('支付 ¥40.00').hitTestable(), findsOneWidget);
      expect(find.text('取消').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (type == 'upgrade' && capture.isNotEmpty) {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            '$capture/confirmation-upgrade-ready.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }
}
