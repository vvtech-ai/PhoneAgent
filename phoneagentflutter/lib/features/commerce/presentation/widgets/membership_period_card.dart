import 'package:flutter/material.dart';
import '../../domain/commerce_catalog.dart';
import '../controller/catalog_controller.dart';
import '../membership_card_presentation.dart';
import 'commerce_display_format.dart';
import 'commerce_product_price.dart';

class MembershipPeriodCard extends StatelessWidget {
  const MembershipPeriodCard({
    super.key,
    required this.state,
    required this.offer,
    required this.onSelect,
    this.onReload,
  });
  final CatalogState state;
  final ProductOffer offer;
  final VoidCallback onSelect;
  final VoidCallback? onReload;

  @override
  Widget build(BuildContext context) {
    final selected = state.selectedMonths == offer.months;
    final original = membershipOriginalPrice(state, offer);
    final relationship = membershipPurchaseLabel(state.membership, offer.level);
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(minHeight: 76),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            width: selected ? 2 : 1,
            color: selected ? const Color(0xFF20242B) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Wrap(
              spacing: 4,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  offer.months == null ? '会员套餐' : periodName(offer.months!),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (relationship != null)
                  Text(
                    relationship,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF1677FF),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 7),
            CommerceProductPrice(
              state: state,
              offer: offer,
              onReload: onReload,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            if (original != null)
              Wrap(
                spacing: 4,
                children: [
                  Text(
                    original % 100 == 0
                        ? '¥${displayPoints(original ~/ 100)}'
                        : money(original),
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFFA1A4AA),
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  Text(
                    '${(offer.cashAmountFen * 10 / original).toStringAsFixed(1)}折',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1677FF),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
