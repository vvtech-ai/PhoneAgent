import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'package:phone_agent/features/commerce/presentation/pages/purchase_result_page.dart';
import 'package:phone_agent/features/commerce/presentation/pages/points_purchase_page.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/commerce_support_contact.dart';
import 'demo_fidelity_test.dart' as fixture;
import 'demo_visual_fixture.dart';
import 'fake_commerce_repository.dart';

void main() {
  testWidgets('邮箱按已发布配置显示并可打开，空邮箱不伪造', (tester) async {
    var contacts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommerceSupportContact(
            email: 'ops@example.com',
            onContact: () => contacts++,
          ),
        ),
      ),
    );
    await tester.tap(find.text('联系客服：ops@example.com'));
    expect(contacts, 1);
    expect(find.textContaining('membership@vv.tech'), findsNothing);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CommerceSupportContact(email: '  ')),
      ),
    );
    expect(find.textContaining('联系客服'), findsNothing);
  });

  testWidgets('会员购买页只有一份邮箱，不重复售后按钮', (tester) async {
    await tester.pumpWidget(MaterialApp(home: fixture.membership()));
    await tester.scrollUntilVisible(find.text('联系客服：membership@vv.tech'), 160);
    expect(find.text('联系客服：membership@vv.tech'), findsOneWidget);
    expect(find.text('专属客服'), findsNothing);
    expect(find.text('标准客服'), findsNothing);
    expect(find.text('联系售后'), findsNothing);
  });

  testWidgets('积分购买按实际支付宝渠道标注，按钮下方显示邮箱', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PointsPurchasePage(
          state: demoVisualCatalog(),
          onBack: () {},
          onBuy: (_) {},
          onAgreement: (_) {},
          onLegal: () {},
        ),
      ),
    );
    final contact = find.text('联系客服：membership@vv.tech');
    await tester.scrollUntilVisible(contact, 160);
    expect(find.text('支付宝购买'), findsOneWidget);
    expect(
      tester.getTopLeft(contact).dy,
      greaterThan(tester.getBottomLeft(find.text('支付宝购买')).dy),
    );
    expect(find.text('微信购买'), findsNothing);
  });

  for (final paid in [false, true]) {
    testWidgets('历史支付页使用邮箱 paid=$paid', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PurchaseResultPage(
            state: PurchaseState(
              order: sampleOrder(
                payment: paid ? 'SUCCEEDED' : 'PENDING',
                fulfillment: paid ? 'SUCCEEDED' : 'NOT_STARTED',
              ),
            ),
            supportEmail: 'ops@example.com',
            onBack: () {},
            onQuery: () {},
            onPay: () {},
            onClose: () {},
            onRecovery: () {},
            onConfirmRecovery: () {},
            onSupport: () {},
            onDone: () {},
          ),
        ),
      );
      await tester.scrollUntilVisible(find.text('联系客服：ops@example.com'), 150);
      expect(find.text('联系售后'), findsNothing);
    });
  }
}
