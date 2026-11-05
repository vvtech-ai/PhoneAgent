import 'package:flutter/material.dart';
import '../../domain/commerce_catalog.dart';
import '../controller/catalog_controller.dart';
import 'commerce_display_format.dart';

/// One price presentation for the existing Flutter offer cards.
class CommerceProductPrice extends StatelessWidget {
  const CommerceProductPrice({
    super.key,
    required this.state,
    required this.offer,
    required this.style,
    this.onReload,
  });
  final CatalogState state;
  final ProductOffer offer;
  final TextStyle style;
  final VoidCallback? onReload;

  @override
  Widget build(BuildContext context) {
    if (state.requiresPlatformProducts && offer.available) {
      if (state.platformStatus == PlatformProductsStatus.loading) {
        return const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      }
      if (state.platformStatus == PlatformProductsStatus.failed) {
        return TextButton(
          onPressed: onReload,
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF1677FF)),
          child: const Text('重新加载'),
        );
      }
    }
    return Text(displayOfferPrice(state, offer), style: style);
  }
}
