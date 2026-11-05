import 'package:flutter/material.dart';
import '../../domain/conversation_messages.dart';
import '../../domain/restaurant_option_presentation.dart';

/// Shared candidate content; selection and submission belong to the card.
class ConversationOptionContent extends StatelessWidget {
  const ConversationOptionContent({
    super.key,
    required this.index,
    required this.option,
  });
  final int index;
  final ConversationOption option;
  static const _blue = Color(0xFF087FF5);

  @override
  Widget build(BuildContext context) {
    final restaurant = option.restaurant;
    final rankFont = restaurant == null ? 13.0 : 12.0;
    final rankSize =
        (MediaQuery.textScalerOf(context).scale(rankFont) * (16 / 12) + 6)
            .clamp(26.0, double.infinity);
    return Row(
      children: [
        Container(
          width: rankSize,
          height: rankSize,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFEAF3FF),
          ),
          child: Text(
            '${index + 1}',
            style: TextStyle(
              fontSize: rankFont,
              height: 16 / 12,
              color: _blue,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                option.label,
                maxLines: restaurant == null ? null : 1,
                overflow: restaurant == null ? null : TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: restaurant == null ? 14 : 13,
                  height: restaurant == null ? null : 18 / 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF101828),
                ),
              ),
              if (restaurant != null)
                ..._restaurantDetails(restaurant)
              else if (option.detail.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    option.detail,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _restaurantDetails(RestaurantOptionPresentation value) => [
    if (value.address.isNotEmpty)
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          value.address,
          style: const TextStyle(
            fontSize: 11,
            height: 16 / 11,
            color: Color(0xFF6B7280),
          ),
        ),
      ),
    if (value.phoneNotice.isNotEmpty)
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          value.phoneNotice,
          style: const TextStyle(
            fontSize: 12,
            height: 16 / 12,
            color: Color(0xFFB45309),
          ),
        ),
      ),
    Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: value.ratingText,
              style: TextStyle(
                fontSize: 12,
                height: 16 / 12,
                color: _blue,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (value.priceCuisineText.isNotEmpty)
              TextSpan(text: ' · ${value.priceCuisineText}'),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          height: 16 / 11,
          color: const Color(0xFF6B7280),
        ),
      ),
    ),
    if (value.locationStatusText.isNotEmpty)
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text.rich(
          TextSpan(
            children: [
              if (value.locationText.isNotEmpty)
                TextSpan(text: value.locationText),
              if (value.openingStatus != null) ...[
                if (value.locationText.isNotEmpty) const TextSpan(text: ' · '),
                TextSpan(
                  text: value.openingStatus,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: value.openingStatus == '营业中'
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFDC2626),
                  ),
                ),
              ],
              if (value.openingHours.isNotEmpty)
                TextSpan(
                  text:
                      '${value.locationText.isNotEmpty || value.openingStatus != null ? ' · ' : ''}${value.openingHours}',
                ),
            ],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            height: 16 / 11,
            color: const Color(0xFF6B7280),
          ),
        ),
      ),
  ];
}
