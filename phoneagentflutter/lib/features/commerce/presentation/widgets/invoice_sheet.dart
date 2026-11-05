import 'package:flutter/material.dart';
import '../../domain/commerce_catalog.dart';
import '../../domain/invoice.dart';
import '../controller/invoice_controller.dart';
import 'commerce_widgets.dart';
import 'invoice_form_fields.dart';
import 'invoice_status_presentation.dart';
import 'commerce_support_contact.dart';

class InvoiceSheet extends StatelessWidget {
  const InvoiceSheet({
    super.key,
    required this.cashAmountFen,
    required this.state,
    required this.draft,
    required this.onClose,
    required this.onTitle,
    required this.onType,
    required this.onChange,
    required this.onSubmit,
    required this.onRefresh,
    this.allowApply = true,
    this.onRetry,
    this.unavailableNotice = '',
    this.supportEmail,
  });
  final int cashAmountFen;
  final InvoiceState state;
  final InvoiceDraft draft;
  final bool allowApply;
  final String unavailableNotice;
  final String? supportEmail;
  final VoidCallback? onRetry;
  final VoidCallback onClose, onSubmit, onRefresh;
  final ValueChanged<String> onTitle, onType;
  final void Function(String, String) onChange;
  Widget _field(String key, String label, {TextInputType? keyboard}) =>
      InvoiceFormField(
        fieldKey: ValueKey('${draft.titleType}-${draft.invoiceType}-$key'),
        label: label,
        value: draft.fields[key] ?? '',
        enabled: !state.busy,
        keyboard: keyboard,
        hint: key == 'taxNumber'
            ? '15–20 位纳税人识别号'
            : key == 'email'
            ? '接收电子发票'
            : key == 'title'
            ? draft.titleType == 'COMPANY'
                  ? '企业名称'
                  : '个人姓名'
            : null,
        onChanged: (value) => onChange(key, value),
      );
  Widget _choices(
    String label,
    String selected,
    Map<String, String> items,
    ValueChanged<String> change,
  ) => InvoiceChoiceRow(
    label: label,
    selected: selected,
    items: items,
    onChanged: change,
    disabled: state.busy
        ? items.keys.toSet()
        : label == '发票类型' && draft.titleType == 'PERSONAL'
        ? const {'SPECIAL'}
        : const {},
  );
  @override
  Widget build(BuildContext context) {
    final invoice = state.invoice;
    final statusNotice = invoiceStatusNotice(invoice);
    final labels = const {
      'INVOICING': '开票中',
      'ISSUED': '已开票',
      'FAILED': '开票失败',
    };
    return PopScope(
      canPop: !state.busy,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height:
              (MediaQuery.sizeOf(context).height *
                          (draft.invoiceType == 'SPECIAL' ? .88 : .78) -
                      MediaQuery.viewInsetsOf(context).bottom)
                  .clamp(220.0, double.infinity),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 9, 18, 12),
            child: Column(
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD6D8DD),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        invoice != null
                            ? '发票详情'
                            : allowApply
                            ? '填写开票信息'
                            : '开票说明',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: state.busy ? null : onClose,
                      icon: const Icon(Icons.close),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF2F3F5),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (invoice != null || allowApply)
                          const Padding(
                            padding: EdgeInsets.only(top: 12, bottom: 16),
                            child: Text(
                              '信息将用于开具并发送电子发票，请仔细核对',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF858991),
                              ),
                            ),
                          ),
                        if (invoice != null || allowApply) ...[
                          const Divider(height: 1, color: Color(0xFFEDF0F3)),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    '可开票金额',
                                    style: TextStyle(
                                      color: Color(0xFF656A73),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      money(
                                        invoice?.cashAmountFen ?? cashAmountFen,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 25,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFFEDF0F3)),
                        ],
                        if (invoice == null && allowApply) ...[
                          _choices('发票类型', draft.invoiceType, const {
                            'ORDINARY': '普通发票',
                            'SPECIAL': '专用发票',
                          }, onType),
                          _choices('抬头类型', draft.titleType, const {
                            'COMPANY': '企业',
                            'PERSONAL': '个人',
                          }, onTitle),
                          _field('title', '发票抬头'),
                          if (draft.titleType == 'COMPANY')
                            _field('taxNumber', '企业税号'),
                          _field(
                            'email',
                            '接收邮箱',
                            keyboard: TextInputType.emailAddress,
                          ),
                          if (draft.invoiceType == 'SPECIAL') ...[
                            _field('companyAddress', '企业注册地址'),
                            _field(
                              'companyPhone',
                              '企业电话',
                              keyboard: TextInputType.phone,
                            ),
                            _field('bankName', '开户银行'),
                            _field(
                              'bankAccount',
                              '银行账号',
                              keyboard: TextInputType.number,
                            ),
                          ],
                        ] else if (invoice != null) ...[
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('开票状态'),
                            subtitle: Text(
                              labels[invoice.status] ?? invoice.status,
                            ),
                          ),
                          if (statusNotice.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                statusNotice,
                                style: const TextStyle(
                                  color: Color(0xFF8A5A13),
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('发票抬头'),
                            subtitle: Text(invoice.titleMasked),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('发票申请号'),
                            subtitle: Text(invoice.invoiceNo),
                          ),
                          if (invoice.status == 'FAILED' &&
                              allowApply &&
                              onRetry != null)
                            CommerceAction(
                              '重新填写开票申请',
                              onPressed: state.busy ? null : onRetry,
                            ),
                        ] else
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              unavailableNotice.isEmpty
                                  ? '当前订单无法发起新的开票申请，请查询已有发票或联系售后'
                                  : unavailableNotice,
                              style: const TextStyle(
                                color: Color(0xFF656A73),
                                height: 1.5,
                              ),
                            ),
                          ),
                        if (!allowApply)
                          CommerceSupportContact(email: supportEmail),
                        if (state.error.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              state.error,
                              style: const TextStyle(color: Color(0xFFD33A3A)),
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                if (state.busy) const LinearProgressIndicator(),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: CommerceAction(
                            '关闭',
                            secondary: true,
                            onPressed: state.busy ? null : onClose,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: CommerceAction(
                            invoice == null && allowApply ? '提交申请' : '查询状态',
                            onPressed: state.busy
                                ? null
                                : invoice == null && allowApply
                                ? onSubmit
                                : onRefresh,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
