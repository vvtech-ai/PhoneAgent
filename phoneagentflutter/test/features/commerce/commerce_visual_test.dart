import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/domain/invoice.dart';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/presentation/controller/catalog_controller.dart';
import 'package:phone_agent/features/commerce/presentation/controller/invoice_controller.dart';
import 'package:phone_agent/features/commerce/presentation/controller/orders_controller.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'package:phone_agent/features/commerce/presentation/pages/membership_page.dart';
import 'package:phone_agent/features/commerce/presentation/pages/points_purchase_page.dart';
import 'package:phone_agent/features/commerce/presentation/pages/commerce_orders_page.dart';
import 'package:phone_agent/features/commerce/presentation/pages/purchase_result_page.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/invoice_sheet.dart';
import 'fake_commerce_repository.dart';
import 'package:phone_agent/features/commerce/data/commerce_dto.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/membership_payment_feedback.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/points_confirmation_sheet.dart';
import 'membership_contract_v2_test.dart' show fixture;
import 'commerce_dto_test.dart' show orderJson;
import 'demo_visual_fixture.dart';
import 'membership_reference_fixture.dart';

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
  final pages = <String, Widget>{
    for (final level in ['FREE', 'BASIC', 'PLUS', 'PREMIUM'])
      'reference-$level': MembershipPage(
        state: membershipReferenceFixture(level),
        modelNames: const {
          'fixture-model-1': 'QwenOmniPlus',
          'fixture-model-2': 'Seeduplex',
          'fixture-exclusive': 'Seeduplex V3',
        },
        availablePoints: 1500,
        heldPoints: 0,
        pointsPerMinute: 100,
        todayDailyGrantReceived: true,
        todayDailyGrantPoints: 100,
        onBack: () {},
        onRefresh: () async {},
        onPoints: () {},
        onOrders: () {},
        onLedger: () {},
        onBuy: () {},
        onLevel: (_) {},
        onMonths: (_) {},
        onSupport: () {},
        onRestore: () {},
        onAgreement: (_) {},
        onLegal: () {},
      ),
    'membership-empty': MembershipPage(
      state: const CatalogState(
        catalog: CommerceCatalog(
          configVersionId: 0,
          revisionNo: 0,
          agreementVersion: '',
          agreementUrl: '',
          supportEmail: '',
          products: [],
        ),
        membership: MembershipCurrent(
          level: 'FREE',
          entitlementVersionId: null,
          benefits: null,
          terms: [],
        ),
      ),
      availablePoints: 1000,
      pointsPerMinute: 100,
      todayDailyGrantReceived: true,
      todayDailyGrantPoints: 100,
      heldPoints: 0,
      onBack: () {},
      onRefresh: () async {},
      onPoints: () {},
      onOrders: () {},
      onLedger: () {},
      onBuy: () {},
      onLevel: (_) {},
      onMonths: (_) {},
      onSupport: () {},
      onRestore: () {},
    ),
    'orders-empty': CommerceOrdersPage(
      state: const OrdersState(),
      onBack: () {},
      onRefresh: () async {},
      onNext: () {},
      onOrder: (_) {},
      onInvoice: (_) {},
    ),
    'membership': MembershipPage(
      state: syntheticCatalog(),
      modelNames: const {
        'fixture-model-1': 'QwenOmniPlus',
        'fixture-model-2': 'Seeduplex',
      },
      availablePoints: 1000,
      pointsPerMinute: 100,
      todayDailyGrantReceived: true,
      todayDailyGrantPoints: 100,
      heldPoints: 0,
      onBack: () {},
      onRefresh: () async {},
      onPoints: () {},
      onOrders: () {},
      onLedger: () {},
      onBuy: () {},
      onLevel: (_) {},
      onMonths: (_) {},
      onSupport: () {},
      onRestore: () {},
      onAgreement: (_) {},
      onLegal: () {},
    ),
    'points': PointsPurchasePage(
      state: syntheticCatalog(),
      onBack: () {},
      onBuy: (_) {},
      onAgreement: (_) {},
      onLegal: () {},
    ),
    'orders': CommerceOrdersPage(
      invoiceStatuses: const {
        'fixture-demo-order-4': 'INVOICING',
        'fixture-demo-order-5': 'ISSUED',
      },
      state: OrdersState(items: demoVisualOrders()),
      onBack: () {},
      onRefresh: () async {},
      onNext: () {},
      onOrder: (_) {},
      onInvoice: (_) {},
    ),
    'membership-success': Scaffold(
      backgroundColor: const Color(0xFF999CA3),
      body: Center(
        child: Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: SizedBox(
            width: 360,
            child: MembershipPaymentFeedback(
              state: PurchaseState(
                order: CommerceDto.order({
                  ...orderJson(),
                  ...fixture('result-new'),
                }),
              ),
              currentMembership: const MembershipCurrent(
                level: 'BASIC',
                currentMonths: 1,
                entitlementVersionId: 1,
                benefits: null,
                terms: [],
              ),
              availablePoints: 9500,
              upgrade: false,
              onDone: () {},
              onQuery: () {},
            ),
          ),
        ),
      ),
    ),
    'points-confirmation': Scaffold(
      backgroundColor: const Color(0xFF999CA3),
      body: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: PointsConfirmationSheet(
            product: demoVisualCatalog().catalog!.products.firstWhere(
              (p) => p.productId == 'p3150',
            ),
            displayPrice: '¥30.00',
            apple: false,
            onConfirm: () {},
          ),
        ),
      ),
    ),
    'result': PurchaseResultPage(
      state: PurchaseState(
        order: sampleOrder(
          payment: 'SUCCEEDED',
          fulfillment: 'EXCEPTION',
          recovery: true,
        ),
      ),
      onBack: () {},
      onQuery: () {},
      onPay: () {},
      onClose: () {},
      supportEmail: 'membership@vv.tech',
      onRecovery: () {},
      onConfirmRecovery: () {},
      onSupport: () {},
      onDone: () {},
    ),
    'result-success': PurchaseResultPage(
      state: PurchaseState(order: demoVisualOrders()[1]),
      supportEmail: 'membership@vv.tech',
      onBack: () {},
      onQuery: () {},
      onPay: () {},
      onClose: () {},
      onRecovery: () {},
      onConfirmRecovery: () {},
      onSupport: () {},
      onDone: () {},
    ),
    'invoice': Stack(
      children: [
        CommerceOrdersPage(
          state: OrdersState(items: demoVisualOrders()),
          onBack: () {},
          onRefresh: () async {},
          onNext: () {},
          onOrder: (_) {},
          onInvoice: (_) {},
        ),
        const Positioned.fill(child: ColoredBox(color: Color(0x700F1218))),
        Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: InvoiceSheet(
              cashAmountFen: 3900,
              state: const InvoiceState(),
              draft: InvoiceDraft()..selectTitle('COMPANY'),
              onClose: () {},
              onTitle: (_) {},
              onType: (_) {},
              onChange: (_, _) {},
              onSubmit: () {},
              onRefresh: () {},
            ),
          ),
        ),
      ],
    ),
  };
  for (final width in [375.0, 390.0, 430.0]) {
    for (final entry in pages.entries) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('${entry.key} width=$width text=$scale', (tester) async {
          final previousShadows = debugDisableShadows;
          try {
            if (capture.isNotEmpty) debugDisableShadows = false;
            tester.view.physicalSize = Size(width, 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            const key = Key('commerce-capture');
            await tester.pumpWidget(
              MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: ThemeData(
                  useMaterial3: true,
                  fontFamily: capture.isEmpty ? null : 'ReferenceText',
                ),
                home: RepaintBoundary(
                  key: key,
                  child: MediaQuery(
                    data: MediaQueryData(
                      size: Size(width, 844),
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: entry.value,
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            if (entry.key == 'membership' &&
                const bool.fromEnvironment('COMMERCE_CAPTURE_PRICE_CARDS')) {
              await tester.ensureVisible(find.text('¥117'));
              await tester.pumpAndSettle();
            }
            if (entry.key == 'points') {
              await tester.tap(find.text('3,150 积分'));
              await tester.pumpAndSettle();
            }
            expect(tester.takeException(), isNull);
            if (capture.isNotEmpty) {
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(key),
              );
              await tester.runAsync(() async {
                final image = await boundary.toImage();
                final pixels = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await File(
                  '$capture/${entry.key}-${width.toInt()}${scale == 1 ? '' : '-2x'}.png',
                ).writeAsBytes(pixels!.buffer.asUint8List());
                image.dispose();
              });
            }
          } finally {
            debugDisableShadows = previousShadows;
          }
        });
      }
    }
  }
}

CatalogState syntheticCatalog() => CatalogState(
  catalog: demoVisualCatalog().catalog,
  channelAvailable: true,
  membership: MembershipCurrent(
    level: 'BASIC',
    entitlementVersionId: 1,
    benefits: null,
    terms: const [],
    currentMonths: 1,
    expiresAt: DateTime.parse('2026-11-15T12:00:00+08:00'),
  ),
);
