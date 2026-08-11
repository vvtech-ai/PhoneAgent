package com.vvtech.aiassistant.data.homeconfig

internal object HomeConfigDefaultImages {
    private const val VERSION_QUERY = "?v=20260727"

    private val legacyUrls = mapOf(
        "restaurant_booking" to
            "https://cdn.chaken.net.cn/ai/homeicon/restaurant-booking-transparent.png",
        "meeting_invite" to
            "https://cdn.chaken.net.cn/ai/homeicon/meeting-invite-transparent.png",
        "apology" to
            "https://cdn.chaken.net.cn/ai/homeicon/apology-transparent.png",
        "event_invite" to
            "https://cdn.chaken.net.cn/ai/homeicon/event-invite-transparent.png",
        "move_car" to
            "https://cdn.chaken.net.cn/ai/homeicon/move-car-transparent.png",
        "sales_promotion" to
            "https://cdn.chaken.net.cn/ai/homeicon/sales-promotion-transparent.png",
        "simultaneous_interpretation" to
            "https://cdn.chaken.net.cn/ai/homeicon/simultaneous-interpretation-transparent.png"
    )

    fun resolve(cardId: String, url: String): String? {
        val legacyUrl = legacyUrls[cardId] ?: return null
        val normalized = url.trim()
        return if (normalized == legacyUrl || normalized == legacyUrl + VERSION_QUERY) {
            legacyUrl + VERSION_QUERY
        } else {
            null
        }
    }
}
