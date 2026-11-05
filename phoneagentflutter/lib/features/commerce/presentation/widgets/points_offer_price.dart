import 'package:flutter/material.dart';
import '../../domain/commerce_catalog.dart';
import '../../domain/points_offer_discount.dart';
import '../controller/catalog_controller.dart';
import 'commerce_product_price.dart';

class PointsOfferPrice extends StatelessWidget {
  const PointsOfferPrice({
    super.key,
    required this.state,
    required this.offer,
    this.onReload,
  });
  final CatalogState state;
  final ProductOffer offer;
  final VoidCallback? onReload;

  @override
  Widget build(BuildContext context) {
    final discount = PointsOfferDiscount.evaluate(
      offer,
      apple: state.requiresPlatformProducts,
      product: state.platformProducts[offer.platformProductId],
      regularProduct: state.platformProducts[offer.regularPlatformProductId],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        CommerceProductPrice(
          state: state,
          offer: offer,
          onReload: onReload,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        if (discount.originalPrice case final original?)
          Text(
            original,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF858991),
              decoration: TextDecoration.lineThrough,
            ),
          ),
        if (discount.discountLabel case final label?)
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF1677FF)),
          ),
        if (discount.membershipLabel case final label?)
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF1677FF)),
          ),
      ],
    );
  }
}
