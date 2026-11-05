import 'package:flutter/material.dart';
import '../controller/catalog_controller.dart';
import 'commerce_widgets.dart';
import 'membership_benefit_list.dart';
import 'membership_price_options.dart';
import 'membership_offer_header.dart';
import 'commerce_support_contact.dart';
import 'commerce_agreement.dart';

class MembershipOffer extends StatelessWidget {
  const MembershipOffer({
    super.key,
    required this.state,
    required this.onMonths,
    required this.onBuy,
    required this.onSupport,
    this.readOnly = false,
    this.onReloadProducts,
    this.onAgreement,
    this.onLegal,
    this.modelNames = const {},
  });
  final CatalogState state;
  final Map<String, String> modelNames;
  final bool readOnly;
  final VoidCallback? onReloadProducts;
  final ValueChanged<bool>? onAgreement;
  final VoidCallback? onLegal;
  final ValueChanged<int> onMonths;
  final VoidCallback onBuy, onSupport;
  @override
  Widget build(BuildContext context) {
    final product = state.selectedProduct;
    final current = state.membership;
    final level = readOnly ? current?.level ?? 'FREE' : state.selectedLevel;
    final benefits = readOnly
        ? current?.benefits
        : state.catalog?.benefitsByLevel[state.selectedLevel] ??
              (current?.level == state.selectedLevel
                  ? current?.benefits
                  : null);
    return CommerceCard(
      contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MembershipOfferHeader(
            selectedLevel: level,
            currentLevel: current?.level,
            concurrentLimit: benefits?['concurrentCallLimit'],
          ),
          const SizedBox(height: 8),
          if (benefits != null) ...[
            MembershipBenefitList(
              level: level,
              benefits: benefits,
              modelNames: modelNames,
              freeBenefits: state.catalog?.benefitsByLevel['FREE'],
            ),
            const SizedBox(height: 10),
          ],
          if (!readOnly &&
              state.selectedLevel != 'FREE' &&
              state.offers.isNotEmpty) ...[
            MembershipPriceOptions(
              state: state,
              onMonths: onMonths,
              onReload: onReloadProducts,
            ),
            const SizedBox(height: 10),
            CommerceAction(
              '购买会员',
              minHeight: 43,
              backgroundColor: const Color(0xFF3478F5),
              onPressed: product != null && state.purchasable(product)
                  ? onBuy
                  : null,
            ),
            if (onAgreement != null && onLegal != null)
              CommerceAgreement(
                accepted: state.agreementAccepted,
                onChanged: onAgreement!,
                onLegal: onLegal!,
                membership: true,
              ),
            CommerceSupportContact(
              email: state.catalog?.supportEmail,
              onContact: onSupport,
            ),
          ],
        ],
      ),
    );
  }
}
