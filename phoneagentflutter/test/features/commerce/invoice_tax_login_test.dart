import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/data/api_invoice_repository.dart';
import 'package:phone_agent/features/commerce/domain/invoice.dart';
import 'package:phone_agent/features/commerce/presentation/controller/invoice_controller.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/invoice_sheet.dart';
import '../../support/synthetic_account_api.dart';

const loginCode = 'SHUIHANG_TAX_LOGIN_REQUIRED';
const processingMessage = '开票暂时受阻，开票方需重新完成税务登录。申请已保留，请稍后查询，无需重复提交。';
const failedMessage = '本次开票未成功，开票方需重新完成税务登录。请联系售后，待恢复后再申请。';

Map<String, Object?> invoiceData(String status, [String? code = loginCode]) => {
  'invoiceNo': 'INV-1',
  'orderNo': 'C1',
  'status': status,
  'cashAmountFen': 3000,
  'titleMasked': '合***',
  'availableFormats': status == 'ISSUED' ? ['PDF'] : [],
  'safeErrorCode': code,
};

Widget sheet(
  CommerceInvoice invoice, {
  TargetPlatform platform = TargetPlatform.android,
  double scale = 1,
  VoidCallback? refresh,
  VoidCallback? retry,
}) => MaterialApp(
  theme: ThemeData(platform: platform),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(
    body: InvoiceSheet(
      cashAmountFen: 3000,
      state: InvoiceState(invoice: invoice),
      draft: InvoiceDraft(),
      onClose: () {},
      onTitle: (_) {},
      onType: (_) {},
      onChange: (_, _) {},
      onSubmit: () => fail('Existing invoice must not submit again'),
      onRefresh: refresh ?? () {},
      onRetry: retry,
    ),
  ),
);

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('tax login processing keeps original query on $platform', (
      tester,
    ) async {
      var queries = 0;
      await tester.pumpWidget(
        sheet(
          ApiInvoiceRepository.parse(invoiceData('INVOICING')),
          platform: platform,
          refresh: () => queries++,
          retry: () => fail('Processing invoice must not offer reapplication'),
        ),
      );
      expect(find.text(processingMessage), findsOneWidget);
      expect(find.text('开票中'), findsOneWidget);
      expect(find.text('INV-1'), findsOneWidget);
      expect(find.text('提交申请'), findsNothing);
      expect(find.text('重新填写开票申请'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.text(loginCode), findsNothing);
      await tester.tap(find.text('查询状态'));
      expect(queries, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('trusted tax login failure keeps explicit retry on $platform', (
      tester,
    ) async {
      var retries = 0;
      await tester.pumpWidget(
        sheet(
          ApiInvoiceRepository.parse(invoiceData('FAILED')),
          platform: platform,
          retry: () => retries++,
        ),
      );
      expect(find.text(failedMessage), findsOneWidget);
      expect(find.text('开票失败'), findsOneWidget);
      expect(find.text(processingMessage), findsNothing);
      expect(retries, 0);
      await tester.ensureVisible(find.text('重新填写开票申请'));
      await tester.tap(find.text('重新填写开票申请'));
      expect(retries, 1);
    });
  }

  for (final sample in [
    invoiceData('ISSUED'),
    invoiceData('INVOICING', 'UNKNOWN_PROVIDER_SECRET'),
    invoiceData('FAILED', null),
  ]) {
    testWidgets(
      'safe display for ${sample['status']} ${sample['safeErrorCode']}',
      (tester) async {
        await tester.pumpWidget(sheet(ApiInvoiceRepository.parse(sample)));
        expect(find.text(processingMessage), findsNothing);
        expect(find.text(failedMessage), findsNothing);
        expect(find.text(loginCode), findsNothing);
        expect(find.text('UNKNOWN_PROVIDER_SECRET'), findsNothing);
        expect(find.text('保存并打开 PDF 文件'), findsNothing);
      },
    );
  }

  testWidgets('tax login explanation scrolls at 320 width and double text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      sheet(ApiInvoiceRepository.parse(invoiceData('INVOICING')), scale: 2),
    );
    expect(find.text(processingMessage), findsOneWidget);
    await tester.ensureVisible(find.text(processingMessage));
    expect(tester.takeException(), isNull);
    expect(find.text('查询状态').hitTestable(), findsOneWidget);
  });

  test(
    'processing login issue reads original invoice without duplicate POST',
    () async {
      final wire = SyntheticAccountApi()..data = invoiceData('INVOICING');
      final controller = InvoiceController(
        'C1',
        ApiInvoiceRepository(wire.api),
      );
      addTearDown(controller.dispose);
      addTearDown(wire.api.close);
      await controller.refresh();
      expect(controller.state.invoice?.safeErrorCode, loginCode);
      controller.retryDraft(invoiceAllowed: true);
      await controller.submit();
      await controller.refresh();
      expect(controller.state.invoice?.invoiceNo, 'INV-1');
      expect(controller.state.invoice?.status, 'INVOICING');
      expect(wire.requests.length, 2);
      expect(wire.requests.every((request) => request.method == 'GET'), isTrue);
      expect(
        wire.requests.every(
          (request) => request.uri.path.endsWith('/orders/C1/invoice'),
        ),
        isTrue,
      );
    },
  );
}
