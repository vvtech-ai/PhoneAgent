import 'package:flutter/material.dart';
import '../../domain/commerce_catalog.dart';
import '../membership_card_presentation.dart';
import 'commerce_widgets.dart';
import 'commerce_agreement.dart';

class MembershipUpgradeDialog extends StatefulWidget {
  const MembershipUpgradeDialog({
    super.key,
    required this.quote,
    required this.product,
    required this.current,
    required this.agreementAccepted,
    required this.onLegal,
    required this.onConfirm,
    this.displayPrice,
  });
  final CommerceQuote quote;
  final String? displayPrice;
  final ProductOffer product;
  final MembershipCurrent? current;
  final bool agreementAccepted;
  final VoidCallback onLegal, onConfirm;
  @override
  State<MembershipUpgradeDialog> createState() =>
      _MembershipUpgradeDialogState();
}

class _MembershipUpgradeDialogState extends State<MembershipUpgradeDialog> {
  late bool _accepted = widget.agreementAccepted;
  Widget _fact(String label, String value) {
    final large = MediaQuery.textScalerOf(context).scale(14) > 21;
    final caption = Text(
      label,
      style: const TextStyle(fontSize: 13, color: Color(0xFF777C84)),
    );
    final detail = Text(
      value,
      textAlign: large ? TextAlign.left : TextAlign.right,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: large
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [caption, const SizedBox(height: 4), detail],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: caption),
                const SizedBox(width: 12),
                Expanded(child: detail),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.white,
    insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 420,
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '确认升级',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            _fact(
              '当前套餐',
              '${membershipName(widget.current?.level ?? 'FREE')}会员',
            ),
            _fact('当前到期日', commerceDate(widget.current?.expiresAt)),
            _fact(
              '升级套餐',
              membershipPlanLabel(
                level: widget.product.level,
                months: widget.product.months,
              ),
            ),
            const Divider(),
            _fact(
              '本次支付',
              widget.displayPrice ??
                  money(
                    widget.quote.cashAmountFen,
                    currency: widget.quote.currency,
                  ),
            ),
            _fact(
              '剩余价值折算时长',
              '${(widget.quote.conversionSeconds / 86400).toStringAsFixed(2)} 天',
            ),
            if (widget.quote.estimatedExpiresAt != null)
              _fact('预计新到期日', commerceDate(widget.quote.estimatedExpiresAt)),
            const SizedBox(height: 8),
            const Text(
              '单次购买，不自动续费；折算时长与新期限以服务端报价和履约结果为准，不退现金。',
              style: TextStyle(fontSize: 12, color: Color(0xFF777C84)),
            ),
            CommerceAgreement(
              accepted: _accepted,
              onChanged: (value) => setState(() => _accepted = value),
              onLegal: widget.onLegal,
            ),
            const SizedBox(height: 12),
            CommerceAction(
              '确认支付',
              onPressed: _accepted ? widget.onConfirm : null,
            ),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
