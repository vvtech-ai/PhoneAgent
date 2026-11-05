import 'package:flutter/material.dart';
import '../controller/catalog_controller.dart';
import '../../domain/commerce_catalog.dart';
import '../widgets/commerce_widgets.dart';
import '../widgets/commerce_agreement.dart';
import '../widgets/points_offer_card.dart';
import '../widgets/commerce_support_contact.dart';
import '../widgets/commerce_read_retry.dart';

class PointsPurchasePage extends StatefulWidget {
  const PointsPurchasePage({
    super.key,
    required this.state,
    required this.onBack,
    required this.onBuy,
    required this.onAgreement,
    required this.onLegal,
    this.onRefresh,
    this.onReloadProducts,
    this.purchaseBlocked = false,
  });
  final CatalogState state;
  final bool purchaseBlocked;
  final VoidCallback? onReloadProducts;
  final VoidCallback onBack, onLegal;
  final ValueChanged<ProductOffer> onBuy;
  final ValueChanged<bool> onAgreement;
  final Future<void> Function()? onRefresh;
  @override
  State<PointsPurchasePage> createState() => _PointsPurchasePageState();
}

class _PointsPurchasePageState extends State<PointsPurchasePage> {
  String? _selectedId;
  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    if (state.catalog?.pointsPackEnabled == false) {
      return CommerceScaffold(
        title: '积分',
        onBack: widget.onBack,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('积分购买暂未开放'),
            if (state.error.isNotEmpty)
              CommerceReadRetry(error: state.error, onRetry: widget.onRefresh),
          ],
        ),
      );
    }
    final offers = state.visibleOffers('POINTS_PACK');
    final selected = offers.where((p) => p.productId == _selectedId);
    final product = selected.isEmpty
        ? (offers.isEmpty ? null : offers.first)
        : selected.first;
    return CommerceScaffold(
      title: '购买积分',
      onBack: widget.onBack,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (offers.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '选择积分包',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '到账积分包含赠送积分，已到账积分永久有效。',
                    style: TextStyle(fontSize: 12, color: Color(0xFF777B84)),
                  ),
                ],
              ),
            ),
          if (state.loading) const Center(child: CircularProgressIndicator()),
          for (final offer in offers)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PointsOfferCard(
                state: state,
                offer: offer,
                selected: product?.productId == offer.productId,
                onReload: widget.onReloadProducts,
                onSelect: () => setState(() => _selectedId = offer.productId),
              ),
            ),
          if (product != null)
            CommerceAction(
              product.channel == 'ALIPAY' ? '支付宝购买' : '确认支付',
              busy: widget.purchaseBlocked,
              onPressed: state.purchasable(product) && !widget.purchaseBlocked
                  ? () => widget.onBuy(product)
                  : null,
            ),
          if (state.requiresPlatformProducts &&
              state.platformStatus == PlatformProductsStatus.ready &&
              !state.channelAvailable &&
              offers.isNotEmpty)
            const Text('当前设备暂不允许 App Store 内购', textAlign: TextAlign.center),
          CommerceSupportContact(email: state.catalog?.supportEmail),
          if (product != null)
            CommerceAgreement(
              accepted: state.agreementAccepted,
              onChanged: widget.onAgreement,
              onLegal: widget.onLegal,
            ),
          if (state.error.isNotEmpty)
            CommerceReadRetry(error: state.error, onRetry: widget.onRefresh),
        ],
      ),
    );
  }
}
