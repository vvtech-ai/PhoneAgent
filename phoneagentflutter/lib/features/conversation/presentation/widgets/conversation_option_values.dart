import '../../domain/conversation_messages.dart';

/// Immutable values of rendered choices, shared by selection and tail owners.
List<Object?> conversationOptionValues(ConversationMessage message) =>
    List<Object?>.unmodifiable([
      message.text,
      message.options.length,
      for (final option in message.options) ...[
        option.label,
        option.restaurant != null,
        if (option.restaurant case final restaurant?) ...[
          restaurant.ratingText,
          restaurant.priceCuisineText,
          restaurant.locationText,
          restaurant.openingStatus,
          restaurant.openingHours,
          restaurant.address,
          restaurant.phoneNotice,
        ] else
          option.detail,
      ],
    ]);
