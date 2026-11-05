import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/presentation/controller/catalog_controller.dart';
import 'package:phone_agent/features/commerce/presentation/pages/points_purchase_page.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/membership_offer.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/membership_period_card.dart';
import 'purchase_card_fixture.dart';

const _capture = String.fromEnvironment('COMMERCE_CAPTURE_DIR');
const _captureKey = ValueKey('purchaseCardsCapture');

void main() {
  setUpAll(() async {
    if (_capture.isEmpty) return;
    for (final entry in const {
      'ReferenceText': String.fromEnvironment('UI_PREFLIGHT_FONT'),
      'MaterialIcons': String.fromEnvironment('UI_PREFLIGHT_ICON_FONT'),
    }.entries) {
      final loader = FontLoader(entry.key)
        ..addFont(File(entry.value).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
    await Directory(_capture).create(recursive: true);
  });

  for (final width in [375.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('会员周期卡横排等高 $width $scale', (tester) async {
        await _render(tester, _membership(), width, scale);
        final cards = find.byType(MembershipPeriodCard);
        expect(cards, findsNWidgets(3));
        final rects = [for (var i = 0; i < 3; i++) tester.getRect(cards.at(i))];
        for (var i = 1; i < 3; i++) {
          expect(rects[i].top, closeTo(rects[0].top, 0.5));
          expect(
            rects[i].height,
            closeTo(rects[0].height, 0.5),
            reason: '不同内容的周期卡仍等高',
          );
          expect(rects[i].width, closeTo(rects[0].width, 0.5));
          expect(rects[i].left, greaterThan(rects[i - 1].right));
        }
        for (final text in [
          '¥39',
          '¥99',
          '¥1234.50',
          '¥117',
          '¥1,500',
          '8.5折',
          '8.2折',
        ]) {
          final found = find.text(text);
          expect(found, findsOneWidget);
          final card = tester.getRect(
            find.ancestor(of: found, matching: cards),
          );
          final value = tester.getRect(found);
          expect(card.inflate(0.5).contains(value.topLeft), isTrue);
          expect(card.inflate(0.5).contains(value.bottomRight), isTrue);
        }
        expect(tester.takeException(), isNull);
        await _save(tester, 'membership', width, scale);
      });

      testWidgets('积分数量赠送在左实价在右 $width $scale', (tester) async {
        await _render(tester, _points(), width, scale);
        final total = tester.getRect(find.text('3,150 积分'));
        final base = tester.getRect(find.text('基础 3,000 + 赠送 150'));
        final price = tester.getRect(find.text('¥30'));
        expect(total.left, closeTo(base.left, 0.5));
        expect(total.bottom, lessThanOrEqualTo(base.top));
        expect(total.right, lessThan(price.left));
        expect(base.right, lessThan(price.left));
        expect(tester.takeException(), isNull);
        await _save(tester, 'points', width, scale);
      });
    }
  }

  testWidgets('不可售会员隐藏周期价格及购买按钮', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      var purchases = 0;
      await _render(
        tester,
        _membership(state: purchaseCardCatalog(), onBuy: () => purchases++),
        390,
        1,
      );
      for (final label in ['月卡', '季卡', '年卡']) {
        expect(find.text(label), findsNothing);
        expect(find.bySemanticsLabel(RegExp(label)), findsNothing);
      }
      expect(find.text('CHANNEL_UNAVAILABLE'), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp('CHANNEL_UNAVAILABLE')),
        findsNothing,
      );
      expect(find.text('暂不可售'), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.text('购买会员'), findsNothing);
      expect(purchases, 0);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('不可售积分隐藏价格及购买按钮', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      var purchases = 0;
      await _render(
        tester,
        _points(state: purchaseCardCatalog(), onBuy: (_) => purchases++),
        390,
        1,
      );
      expect(find.text('CHANNEL_UNAVAILABLE'), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp('CHANNEL_UNAVAILABLE')),
        findsNothing,
      );
      expect(find.text('暂不可售'), findsNothing);
      expect(find.text('当前支付渠道暂不可用'), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.text('支付宝购买'), findsNothing);
      expect(purchases, 0);
      expect(find.text('微信购买'), findsNothing);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('单个已发布周期不补造其它价格卡', (tester) async {
    final published = purchaseCardCatalog(unavailable: false).catalog!;
    final state = CatalogState(
      catalog: CommerceCatalog(
        configVersionId: published.configVersionId,
        revisionNo: published.revisionNo,
        agreementVersion: published.agreementVersion,
        agreementUrl: published.agreementUrl,
        supportEmail: published.supportEmail,
        products: [published.products.first],
      ),
    );
    await _render(tester, _membership(state: state), 390, 1);
    expect(find.byType(MembershipPeriodCard), findsOneWidget);
    expect(find.text('月卡'), findsOneWidget);
    expect(find.text('季卡'), findsNothing);
    expect(find.text('年卡'), findsNothing);
  });
}

Widget _membership({VoidCallback? onBuy, CatalogState? state}) => Scaffold(
  body: SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: MembershipOffer(
        state: state ?? purchaseCardCatalog(unavailable: false),
        onMonths: (_) {},
        onBuy: onBuy ?? () {},
        onSupport: () {},
      ),
    ),
  ),
);

Widget _points({ValueChanged<ProductOffer>? onBuy, CatalogState? state}) =>
    PointsPurchasePage(
      state: state ?? purchaseCardCatalog(unavailable: false),
      onBack: () {},
      onBuy: onBuy ?? (_) {},
      onAgreement: (_) {},
      onLegal: () {},
    );

Future<void> _render(
  WidgetTester tester,
  Widget child,
  double width,
  double scale,
) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(fontFamily: _capture.isEmpty ? null : 'ReferenceText'),
      home: RepaintBoundary(
        key: _captureKey,
        child: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 844),
            textScaler: TextScaler.linear(scale),
          ),
          child: child,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _save(
  WidgetTester tester,
  String name,
  double width,
  double scale,
) async {
  if (_capture.isEmpty) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_captureKey),
    );
    final pixels = await boundary.toImage();
    try {
      final png = await pixels.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '$_capture/$name-${width.toInt()}-${scale.toInt()}x.png',
      ).writeAsBytes(png!.buffer.asUint8List());
    } finally {
      pixels.dispose();
    }
  });
}
