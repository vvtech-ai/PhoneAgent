import 'package:flutter/material.dart';
import '../membership_benefit_items.dart';

/// Shared typography for system monthly points and operator-written benefits.
class MembershipBenefitRow extends StatelessWidget {
  const MembershipBenefitRow({
    super.key,
    required this.item,
    this.last = false,
  });

  final MembershipBenefitItem item;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final highlight = item.highlight;
    final offset = highlight == null ? -1 : item.title.indexOf(highlight);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: item.large ? 9 : 7),
      decoration: last
          ? null
          : const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFEDF0F4))),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: offset < 0
                  ? [TextSpan(text: item.title)]
                  : [
                      TextSpan(text: item.title.substring(0, offset)),
                      TextSpan(
                        text: highlight,
                        style: const TextStyle(
                          color: Color(0xFF3478F5),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: item.title.substring(offset + highlight!.length),
                      ),
                    ],
            ),
            style: TextStyle(
              fontSize: item.large ? 18 : 13,
              height: item.large ? 1.4 : 1.5,
              fontWeight: item.large ? FontWeight.w700 : FontWeight.w600,
              color: const Color(0xFF202532),
            ),
          ),
          if (item.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.description,
              style: TextStyle(
                fontSize: item.large ? 13 : 11,
                height: 1.6,
                color: item.large
                    ? const Color(0xFF7D8491)
                    : const Color(0xFF858991),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
