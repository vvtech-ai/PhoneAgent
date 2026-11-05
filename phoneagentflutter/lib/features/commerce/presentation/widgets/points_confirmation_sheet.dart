import 'package:flutter/material.dart';
import '../../domain/commerce_catalog.dart';
import 'commerce_display_format.dart';
import 'commerce_widgets.dart';

class PointsConfirmationSheet extends StatefulWidget {
  const PointsConfirmationSheet({
    super.key,
    required this.product,
    required this.displayPrice,
    required this.apple,
    required this.onConfirm,
  });
  final ProductOffer product;
  final String displayPrice;
  final bool apple;
  final VoidCallback onConfirm;
  @override
  State<PointsConfirmationSheet> createState() =>
      _PointsConfirmationSheetState();
}

class _PointsConfirmationSheetState extends State<PointsConfirmationSheet> {
  bool _submitting = false;
  Widget _row(String label, String value, {bool price = false}) => Padding(
    padding: EdgeInsets.only(top: price ? 14 : 12, bottom: price ? 14 : 0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: price ? 13 : 14,
            color: const Color(0xFF737984),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: price ? 30 : 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF202532),
            ),
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_submitting,
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD6D8DD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '确认支付',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  style: IconButton.styleFrom(
                    fixedSize: const Size(44, 44),
                    backgroundColor: const Color(0xFFF2F3F5),
                    shape: const CircleBorder(),
                  ),
                  onPressed: _submitting
                      ? null
                      : () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close),
                  tooltip: '关闭支付弹窗',
                ),
              ],
            ),
            _row('基础积分', displayPoints(widget.product.basePoints)),
            _row('赠送积分', displayPoints(widget.product.bonusPoints)),
            _row(
              '到账总积分',
              '${displayPoints(widget.product.basePoints + widget.product.bonusPoints)} 积分',
            ),
            _row('支付方式', widget.apple ? 'Apple 系统内购' : '支付宝'),
            _row('支付金额', widget.displayPrice, price: true),
            const Divider(height: 1, color: Color(0xFFEDF0F4)),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text(
                '支付成功后积分到账，积分长期有效。',
                style: TextStyle(fontSize: 13, color: Color(0xFF737984)),
              ),
            ),
            CommerceAction(
              '确认支付 ${widget.displayPrice}',
              onPressed: _submitting
                  ? null
                  : () {
                      if (_submitting) return;
                      setState(() => _submitting = true);
                      widget.onConfirm();
                    },
            ),
          ],
        ),
      ),
    ),
  );
}
