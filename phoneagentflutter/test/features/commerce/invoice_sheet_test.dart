import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/domain/invoice.dart';
import 'package:phone_agent/features/commerce/data/api_invoice_repository.dart';
import 'package:phone_agent/features/commerce/presentation/controller/invoice_controller.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/invoice_sheet.dart';

void main() {
  for (final status in ['INVOICING', 'ISSUED']) {
    testWidgets(
      'real invoice $status keeps status without file or email entry',
      (tester) async {
        final invoice = ApiInvoiceRepository.parse({
          'invoiceNo': 'INV-1',
          'orderNo': 'C1',
          'status': status,
          'cashAmountFen': 3000,
          'titleMasked': '个***',
          'safeErrorCode': null,
          'availableFormats': status == 'ISSUED' ? ['PDF', 'OFD', 'XML'] : [],
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InvoiceSheet(
                cashAmountFen: 3000,
                state: InvoiceState(invoice: invoice),
                draft: InvoiceDraft(),
                onClose: () {},
                onTitle: (_) {},
                onType: (_) {},
                onChange: (_, _) {},
                onSubmit: () {},
                onRefresh: () {},
              ),
            ),
          ),
        );
        expect(find.text(status == 'ISSUED' ? '已开票' : '开票中'), findsOneWidget);
        expect(find.textContaining('保存并打开'), findsNothing);
        expect(find.byType(TextField), findsNothing);
        expect(find.text('查询状态'), findsOneWidget);
      },
    );
  }
  testWidgets('invoice has read only amount and keyboard-safe fixed actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InvoiceSheet(
            cashAmountFen: 3000,
            state: const InvoiceState(),
            draft: InvoiceDraft(),
            onClose: () {},
            onTitle: (_) {},
            onType: (_) {},
            onChange: (_, _) {},
            onSubmit: () {},
            onRefresh: () {},
          ),
        ),
      ),
    );
    expect(find.text('¥30.00'), findsOneWidget);
    expect(find.text('提交申请'), findsOneWidget);
    expect(find.text('企业税号'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
