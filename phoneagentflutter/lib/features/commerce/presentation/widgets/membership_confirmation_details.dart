import 'membership_activation_rules.dart';
import 'package:flutter/material.dart';
import '../../domain/commerce_catalog.dart';
import 'commerce_widgets.dart';
import 'commerce_display_format.dart';
import 'membership_status_caption.dart';

/// Displays the trusted quote without recalculating price or queue order.
class MembershipConfirmationDetails extends StatelessWidget {
  const MembershipConfirmationDetails({
    super.key,
    required this.quote,
    required this.productName,
    required this.displayPrice,
  });
  final CommerceQuote quote;
  final String productName, displayPrice;
  Widget _amount(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: LayoutBuilder(
      builder: (context, constraints) {
        const labelStyle = TextStyle(
          fontSize: 14,
          height: 1.5,
          color: Color(0xFF858991),
        );
        const priceStyle = TextStyle(
          fontSize: 23,
          height: 1.15,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1677FF),
        );
        double width(String text, TextStyle style) {
          final painter = TextPainter(
            text: TextSpan(
              text: text,
              style: DefaultTextStyle.of(context).style.merge(style),
            ),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          final result = painter.width;
          painter.dispose();
          return result;
        }

        final labelWidget = Text(label, style: labelStyle);
        final price = FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            value,
            key: const ValueKey('membership-confirmation-price'),
            maxLines: 1,
            softWrap: false,
            style: priceStyle,
          ),
        );
        if (width(label, labelStyle) + 16 + width(value, priceStyle) >
            constraints.maxWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              labelWidget,
              const SizedBox(height: 6),
              Align(alignment: Alignment.centerRight, child: price),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            labelWidget,
            const SizedBox(width: 16),
            Expanded(child: price),
          ],
        );
      },
    ),
  );
  Widget _row(String label, String value, {bool amount = false}) => amount
      ? _amount(label, value)
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFF858991),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF202329),
                  ),
                ),
              ),
            ],
          ),
        );
  @override
  Widget build(BuildContext context) {
    final p = quote.membershipPreview;
    const note = TextStyle(
      fontSize: 13,
      height: 1.65,
      color: Color(0xFF68707C),
    );
    if (p == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row('购买套餐', productName),
          _row('本次应付', displayPrice, amount: true),
          const Text('单次购买，不自动续费。', style: note),
        ],
      );
    }
    final paused = p.pausedEntitlement;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (paused != null)
          _row(
            '当前套餐',
            '${membershipName(paused.level)}会员 · ${membershipPeriodCaption(paused.months)}',
          ),
        _row('使用时长', '${p.targetMonths}个月'),
        _row(
          p.queued ? '预计生效' : '权益生效',
          p.queued
              ? p.estimatedStartsAt == null
                    ? '待前序套餐用完后'
                    : commerceDate(p.estimatedStartsAt).replaceAll('-', '/')
              : '支付成功后立即生效',
        ),
        _row(
          p.queued ? '首期积分' : '本次到账',
          '${displayPoints(p.queued ? p.firstGrantPoints : p.immediateGrantPoints)}积分',
        ),
        if (p.queued)
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '生效时到账',
              style: const TextStyle(
                fontSize: 12,
                height: 1.5,
                color: Color(0xFF90949C),
              ),
            ),
          ),
        if (p.totalPeriods > 1)
          _row(
            '发放计划',
            '每月${displayPoints(p.basePointsPerPeriod + p.bonusPointsPerPeriod)} · 共${p.totalPeriods}期',
          ),
        _row('本次应付', displayPrice, amount: true),
        const SizedBox(height: 6),
        Text(
          paused != null
              ? '原${membershipName(paused.level)}会员剩余权益暂停保留，新套餐使用完后按顺序恢复。'
              : p.queued
              ? p.precedingEntitlements.length == 1
                    ? '当前会员使用完后生效；等待期间不消耗会员时长。'
                    : '前方${p.precedingEntitlements.length}份套餐（含当前）使用完后生效；等待期间不消耗会员时长。'
              : '会员从支付成功时开始计算，已到账积分永久有效。',
          style: note,
        ),
        if (p.targetLevel == 'BASIC' || p.targetLevel == 'PLUS')
          MembershipActivationRules(preview: p),
      ],
    );
  }
}
