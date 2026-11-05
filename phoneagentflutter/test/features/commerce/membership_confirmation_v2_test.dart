import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/data/commerce_dto.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/membership_confirmation_sheet.dart';
import 'membership_contract_v2_test.dart' show fixture;

void main() {
  setUpAll(() async {
    const path = String.fromEnvironment('UI_PREFLIGHT_FONT');
    if (path.isNotEmpty) {
      final loader = FontLoader('ReferenceText')
        ..addFont(File(path).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });

  testWidgets(
    'long queue and large text remain scrollable with explicit confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(375, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final data = fixture('quote-lower_queued');
      final preview = Map<String, Object?>.from(
        data['membershipPreview'] as Map,
      );
      final source = Map<String, Object?>.from(
        (preview['precedingEntitlements'] as List).first as Map,
      );
      preview['precedingEntitlements'] = List.generate(
        20,
        (i) => {...source, 'position': i + 1, 'entitlementId': '${203 + i}'},
      );
      final quote = CommerceDto.quote({
        ...data,
        'membershipPreview': preview,
        'quoteId': 'q',
        'productId': 'm',
        'configVersionId': 1,
        'cashAmountFen': 4000,
        'currency': 'CNY',
        'expiresAt': '2099-01-01T00:00:00+08:00',
      });
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            fontFamily:
                const String.fromEnvironment('UI_PREFLIGHT_FONT').isEmpty
                ? null
                : 'ReferenceText',
          ),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(375, 900),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: RepaintBoundary(
                key: boundary,
                child: ColoredBox(
                  color: Colors.white,
                  child: MembershipConfirmationSheet(
                    agreementAccepted: true,
                    quote: quote,
                    productName: '初级会员包月',
                    displayPrice: '¥40.00',
                    apple: false,
                    onConfirm: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory('build/test-results').createSync(recursive: true);
        File(
          'build/test-results/membership-v2-confirmation-large.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.ensureVisible(find.text('支付 ¥40.00'));
      await tester.pump();
      expect(find.text('支付 ¥40.00').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [375.0, 390.0, 430.0]) {
    for (final type in ['new', 'upgrade', 'renew', 'lower_queued']) {
      testWidgets(
        '$type confirmation requires explicit payment and agreement at $width',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final quote = CommerceDto.quote({
            ...fixture('quote-$type'),
            'quoteId': 'q',
            'productId': 'm',
            'configVersionId': 1,
            'cashAmountFen': 4000,
            'currency': 'CNY',
            'expiresAt': '2099-01-01T00:00:00+08:00',
          });
          var submitted = 0;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: MembershipConfirmationSheet(
                  agreementAccepted: true,
                  quote: quote,
                  productName: '会员包月',
                  displayPrice: '¥40.00',
                  apple: false,
                  onConfirm: () {
                    submitted++;
                  },
                ),
              ),
            ),
          );
          expect(
            find.text(switch (type) {
              'new' => '开通初级会员 · 月卡',
              'upgrade' => '升级至高级会员 · 月卡',
              'renew' => '续购高级会员 · 月卡',
              _ => '购买初级会员 · 月卡',
            }),
            findsOneWidget,
          );
          expect(find.byType(Checkbox), findsNothing);
          expect(submitted, 0);
          await tester.ensureVisible(find.text('支付宝'));
          await tester.tap(find.text('支付宝'));
          await tester.pump();
          await tester.ensureVisible(find.text('支付 ¥40.00'));
          await tester.tap(find.text('支付 ¥40.00'));
          await tester.pump();
          expect(submitted, 1);
          expect(find.text('支付处理中…'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
