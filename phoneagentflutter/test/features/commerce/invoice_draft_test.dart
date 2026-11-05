import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/domain/invoice.dart';

void main() {
  test('personal clears sensitive company fields and returns to ordinary', () {
    final draft = InvoiceDraft()
      ..selectTitle('COMPANY')
      ..selectType('SPECIAL')
      ..set('title', '合成公司')
      ..set('taxNumber', '91300000123456789A')
      ..set('bankAccount', '123456')
      ..set('companyAddress', '合成地址')
      ..set('email', 'buyer@example.com');
    draft.selectTitle('PERSONAL');
    expect(draft.invoiceType, 'ORDINARY');
    expect(draft.fields['taxNumber'], isEmpty);
    expect(draft.fields['bankAccount'], isEmpty);
    draft.selectTitle('COMPANY');
    expect(draft.fields['title'], isEmpty);
    expect(draft.fields['bankAccount'], isEmpty);
  });
  test('personal special is unavailable and required fields are validated', () {
    final draft = InvoiceDraft()..selectType('SPECIAL');
    expect(draft.invoiceType, 'ORDINARY');
    expect(draft.validation, isNotEmpty);
    draft.set('title', '合成个人');
    draft.set('email', 'buyer@example.com');
    expect(draft.validation, isEmpty);
    draft.selectTitle('COMPANY');
    draft.set('title', '合成公司');
    draft.set('email', 'buyer@example.com');
    expect(draft.validation, contains('税号'));
  });
}
