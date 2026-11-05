import 'package:flutter/material.dart';
import '../../domain/commerce_catalog.dart';
import '../controller/catalog_controller.dart';
import 'commerce_display_format.dart';
import 'points_offer_price.dart';

class PointsOfferCard extends StatelessWidget {
  const PointsOfferCard({
    super.key,
    required this.state,
    required this.offer,
    required this.selected,
    required this.onSelect,
    this.onReload,
  });
  final CatalogState state;
  final ProductOffer offer;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback? onReload;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          constraints: const BoxConstraints(minHeight: 76),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? const Color(0xFF1677FF)
                  : const Color(0xFFECEFF3),
            ),
            boxShadow: selected
                ? const [BoxShadow(color: Color(0x221677FF), spreadRadius: 2)]
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${displayPoints(offer.basePoints + offer.bonusPoints)} 积分',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '基础 ${displayPoints(offer.basePoints)}${offer.bonusPoints > 0 ? ' + 赠送 ${displayPoints(offer.bonusPoints)}' : ''}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF858991),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              PointsOfferPrice(state: state, offer: offer, onReload: onReload),
            ],
          ),
        ),
      ),
    ),
  );
}
