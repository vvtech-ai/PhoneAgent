import 'package:flutter/material.dart';
import '../controller/catalog_controller.dart';
import 'membership_period_card.dart';

/// Shares the tallest real offer's height without limiting text scaling.
class MembershipPriceOptions extends StatelessWidget {
  const MembershipPriceOptions({
    super.key,
    required this.state,
    required this.onMonths,
    this.onReload,
  });
  final CatalogState state;
  final VoidCallback? onReload;
  final ValueChanged<int> onMonths;

  @override
  Widget build(BuildContext context) {
    final offers = state.offers..sort((a, b) => a.months!.compareTo(b.months!));
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final offer in offers)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: MembershipPeriodCard(
                  state: state,
                  onReload: onReload,
                  offer: offer,
                  onSelect: () => onMonths(offer.months!),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
