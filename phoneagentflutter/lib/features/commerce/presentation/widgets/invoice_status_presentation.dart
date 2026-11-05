import '../../domain/invoice.dart';

String invoiceStatusNotice(CommerceInvoice? invoice) {
  if (invoice?.safeErrorCode != 'SHUIHANG_TAX_LOGIN_REQUIRED') return '';
  return switch (invoice?.status) {
    'INVOICING' => '开票暂时受阻，开票方需重新完成税务登录。申请已保留，请稍后查询，无需重复提交。',
    'FAILED' => '本次开票未成功，开票方需重新完成税务登录。请联系售后，待恢复后再申请。',
    _ => '',
  };
}
