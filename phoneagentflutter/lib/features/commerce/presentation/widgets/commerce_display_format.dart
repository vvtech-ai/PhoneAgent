import '../../domain/commerce_catalog.dart';
import '../controller/catalog_controller.dart';

String displayPoints(int value) => value.toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (match) => ',',
);

String displayOfferPrice(CatalogState state, ProductOffer offer) {
  if (state.requiresPlatformProducts || offer.cashAmountFen % 100 != 0) {
    return state.price(offer);
  }
  final prefix = offer.currency == 'CNY' ? '¥' : '${offer.currency} ';
  return '$prefix${displayPoints(offer.cashAmountFen ~/ 100)}';
}

int? membershipOriginalPrice(CatalogState state, ProductOffer offer) {
  final original = offer.originalCashAmountFen;
  if (state.requiresPlatformProducts ||
      offer.productType != 'MEMBERSHIP' ||
      !const {1, 3, 12}.contains(offer.months) ||
      offer.currency != 'CNY' ||
      offer.cashAmountFen <= 0 ||
      original == null ||
      original <= offer.cashAmountFen) {
    return null;
  }
  return original;
}
