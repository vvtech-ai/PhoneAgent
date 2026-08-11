package com.vvtech.aiassistant.features.assistant_home

import com.vvtech.aiassistant.R

internal fun assistantHomeCardImageRes(cardId: String): Int? = when (cardId) {
    "restaurant_booking" -> R.drawable.home_card_restaurant_booking
    "meeting_invite" -> R.drawable.home_card_meeting_invite
    "apology" -> R.drawable.home_card_apology
    "event_invite" -> R.drawable.home_card_event_invite
    "move_car" -> R.drawable.home_card_move_car
    "sales_promotion" -> R.drawable.home_card_sales_promotion
    "simultaneous_interpretation" -> R.drawable.home_card_simultaneous_interpretation
    else -> null
}
