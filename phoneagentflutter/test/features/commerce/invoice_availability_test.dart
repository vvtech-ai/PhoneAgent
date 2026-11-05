import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/commerce_providers.dart';
import 'package:phone_agent/features/commerce/data/commerce_dto.dart';
import 'package:phone_agent/features/commerce/domain/commerce_order.dart';
import 'package:phone_agent/features/commerce/domain/invoice.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'package:phone_agent/features/commerce/presentation/pages/invoice_route.dart';
import 'package:phone_agent/features/commerce/presentation/pages/purchase_result_page.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/commerce_order_action.dart';
import 'commerce_dto_test.dart' show orderJson;
import 'fake_commerce_repository.dart';

const foreignNotice = '该订单使用外币支付，暂不支持在 App 内申请发票';
const fractionalNotice = '该订单金额暂不支持在线开票，请联系售后协助处理';

CommerceOrder receiptOrder({
  String currency = 'USD',
  String amount = '4990',
  bool allowed = false,
}) => CommerceDto.order({
  ...orderJson(),
  'channel': 'APPLE_IAP',
  'invoiceAllowed': allowed,
  'cashPaidFen': currency == 'CNY' && int.parse(amount) % 10 == 0
      ? int.parse(amount) ~/ 10
      : 0,
  'platformPaidCurrency': currency,
  'platformPaidAmountMilliunits': amount,
});

class _Invoices implements InvoiceRepository {
  CommerceInvoice? current;
  int reads = 0, submits = 0;
  @override
  Future<CommerceInvoice?> invoice(String orderNo) async {
    reads++;
    return current;
  }

  @override
  Future<CommerceInvoice> apply(
    String orderNo,
    Map<String, Object?> request,
  ) async {
    submits++;
    throw StateError('No invoice submission in display test');
  }
}

Future<void> _openInvoice(
  WidgetTester tester,
  CommerceOrder order,
  _Invoices repo, {
  TargetPlatform platform = TargetPlatform.android,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        loginEpochProvider.overrideWithValue(1),
        commerceRepositoryProvider.overrideWithValue(FakeCommerceRepository()),
        paymentLauncherProvider.overrideWithValue(FakePaymentLauncher()),
        invoiceRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showCommerceInvoice(context, order),
              child: const Text('打开原单发票'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开原单发票'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'invoice application shows server available net instead of reference or paid cash',
    (tester) async {
      final order = CommerceDto.order({
        ...orderJson(),
        'channel': 'APPLE_IAP',
        'cashAmountFen': 3900,
        'cashPaidFen': 3800,
        'invoiceAllowed': true,
        'platformPaidCurrency': 'CNY',
        'platformPaidAmountMilliunits': '38000',
        'invoiceAvailableFen': 3300,
      });
      await _openInvoice(tester, order, _Invoices());
      expect(find.text('¥33.00'), findsOneWidget);
      expect(find.text('¥38.00'), findsNothing);
      expect(find.text('¥39.00'), findsNothing);
      expect(find.text('提交申请'), findsOneWidget);
    },
  );
  test(
    'invalid invoice available amount cannot silently replace paid cash',
    () {
      for (final amount in <Object>[-1, 3801, 3300.0, '3300', true]) {
        expect(
          () => CommerceDto.order({
            ...orderJson(),
            'cashPaidFen': 3800,
            'invoiceAvailableFen': amount,
          }),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'missing nullable net amount keeps legacy compatibility and valid zero remains zero',
    () {
      expect(CommerceDto.order(orderJson()).invoiceAvailableFen, isNull);
      expect(
        CommerceDto.order({
          ...orderJson(),
          'invoiceAvailableFen': null,
        }).invoiceAvailableFen,
        isNull,
      );
      expect(
        CommerceDto.order({
          ...orderJson(),
          'invoiceAvailableFen': 0,
        }).invoiceAvailableFen,
        0,
      );
    },
  );
  testWidgets(
    'zero available amount never exposes a new application for ineligible order',
    (tester) async {
      final order = CommerceDto.order({
        ...orderJson(),
        'invoiceAllowed': false,
        'cashPaidFen': 3800,
        'invoiceAvailableFen': 0,
      });
      await _openInvoice(tester, order, _Invoices());
      expect(find.text('提交申请'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('¥0.00'), findsNothing);
      expect(find.text('当前订单无法发起新的开票申请，请查询已有发票或联系售后'), findsOneWidget);
    },
  );
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform foreign invoice direct route explains without form or false CNY amount at 320 large text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = _Invoices();
        await _openInvoice(
          tester,
          receiptOrder(),
          repo,
          platform: platform,
          scale: 2,
        );
        expect(find.text(foreignNotice), findsOneWidget);
        expect(find.text('开票说明'), findsOneWidget);
        expect(find.text('¥0.00'), findsNothing);
        expect(find.byType(TextField), findsNothing);
        expect(find.text('提交申请'), findsNothing);
        await tester.ensureVisible(find.textContaining('support@example.com'));
        expect(tester.takeException(), isNull);
        expect(repo.submits, 0);
        await tester.tap(find.text('查询状态'));
        await tester.pumpAndSettle();
        expect(repo.reads, 2);
      },
    );
    testWidgets('$platform eligible Apple CNY retains invoice form', (
      tester,
    ) async {
      await _openInvoice(
        tester,
        receiptOrder(currency: 'CNY', amount: '39000', allowed: true),
        _Invoices(),
        platform: platform,
      );
      expect(find.text('提交申请'), findsOneWidget);
      expect(find.text('¥39.00'), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);
      expect(find.text(foreignNotice), findsNothing);
    });
  }
  for (final sample in [('300001', fractionalNotice), ('0', '该订单无可开票的实付金额')]) {
    testWidgets('CNY ${sample.$1} has exact reason', (tester) async {
      await _openInvoice(
        tester,
        receiptOrder(currency: 'CNY', amount: sample.$1),
        _Invoices(),
      );
      expect(find.text(sample.$2), findsOneWidget);
      expect(find.text('提交申请'), findsNothing);
    });
  }
  testWidgets(
    'order action and completed details expose explanation without another modal',
    (tester) async {
      final order = receiptOrder();
      var opens = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommerceOrderAction(
              order: order,
              onOrder: () {},
              onInvoice: () => opens++,
            ),
          ),
        ),
      );
      expect(find.text('开票说明'), findsOneWidget);
      await tester.tap(find.text('开票说明'));
      expect(opens, 1);
      await tester.pumpWidget(
        MaterialApp(
          home: PurchaseResultPage(
            state: PurchaseState(order: order),
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
      expect(find.text(foreignNotice), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
  for (final status in ['INVOICING', 'ISSUED']) {
    testWidgets('existing $status invoice remains authoritative', (
      tester,
    ) async {
      final repo = _Invoices()
        ..current = CommerceInvoice(
          invoiceNo: 'INV-1',
          orderNo: 'order-1',
          status: status,
          cashAmountFen: 3900,
          titleMasked: '合***',
          availableFormats: status == 'ISSUED' ? ['PDF'] : [],
        );
      await _openInvoice(
        tester,
        receiptOrder(currency: 'CNY', amount: '39000'),
        repo,
      );
      expect(find.text(status == 'ISSUED' ? '已开票' : '开票中'), findsOneWidget);
      expect(find.text('提交申请'), findsNothing);
      expect(repo.submits, 0);
    });
  }
}
