import 'package:flutter/material.dart';
import '../../domain/commerce_catalog.dart';
import 'membership_confirmation_details.dart';
import 'membership_confirmation_payment.dart';
import 'membership_status_caption.dart';

class MembershipConfirmationSheet extends StatefulWidget {
  const MembershipConfirmationSheet({
    super.key,
    required this.quote,
    required this.productName,
    required this.displayPrice,
    required this.apple,
    required this.onConfirm,
    this.paymentAvailable = true,
    this.agreementAccepted = false,
  });
  final CommerceQuote quote;
  final String productName, displayPrice;
  final bool apple, paymentAvailable;
  final bool agreementAccepted;
  final VoidCallback onConfirm;
  @override
  State<MembershipConfirmationSheet> createState() =>
      _MembershipConfirmationSheetState();
}

class _MembershipConfirmationSheetState
    extends State<MembershipConfirmationSheet> {
  bool _selected = true, _submitting = false;

  @override
  Widget build(BuildContext context) {
    final preview = widget.quote.membershipPreview;
    final title = preview == null
        ? switch (widget.quote.purchaseType) {
            'NEW' => '确认开通会员？',
            'UPGRADE' => '确认升级会员？',
            'RENEW' => '确认续购会员？',
            _ => '确认购买会员？',
          }
        : '${switch (widget.quote.purchaseType) {
            'NEW' => '开通',
            'UPGRADE' => '升级至',
            'RENEW' => '续购',
            _ => '购买',
          }}${membershipName(preview.targetLevel)}会员 · ${membershipPeriodCaption(preview.targetMonths)}';
    return PopScope(
      canPop: !_submitting,
      child: Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          key: const ValueKey('membership-confirmation-card'),
          width: 360,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 21,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF202329),
                  ),
                ),
                const SizedBox(height: 22),
                MembershipConfirmationDetails(
                  quote: widget.quote,
                  productName: widget.productName,
                  displayPrice: widget.displayPrice,
                ),
                MembershipConfirmationPayment(
                  apple: widget.apple,
                  available: widget.paymentAvailable,
                  selected: _selected,
                  accepted: widget.agreementAccepted,
                  submitting: _submitting,
                  displayPrice: widget.displayPrice,
                  onSelect: () => setState(() => _selected = true),
                  onCancel: () => Navigator.pop(context, false),
                  onConfirm: () {
                    if (_submitting ||
                        !widget.agreementAccepted ||
                        !_selected ||
                        !widget.paymentAvailable) {
                      return;
                    }
                    setState(() => _submitting = true);
                    widget.onConfirm();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
