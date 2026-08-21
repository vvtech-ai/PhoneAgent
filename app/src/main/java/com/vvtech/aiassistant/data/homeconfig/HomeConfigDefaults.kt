package com.vvtech.aiassistant.data.homeconfig

import com.vvtech.aiassistant.features.assistant_home.domain.HomeCard
import com.vvtech.aiassistant.features.assistant_home.domain.HomeCardStatus
import com.vvtech.aiassistant.features.assistant_home.domain.HomeConfig
import com.vvtech.aiassistant.features.assistant_home.domain.HomeEntryAction
import com.vvtech.aiassistant.features.assistant_home.domain.HomeSlogan

internal object HomeConfigDefaults {
    fun create(): HomeConfig = HomeConfig(
        configVersion = "builtin-1",
        slogans = listOf(
            HomeSlogan("primary", "Give Me a Task", "I can make the call for you", 1),
            HomeSlogan("secondary", "What Can I Do for You?", "I can make the call for you", 2)
        ),
        cards = listOf(
            card("restaurant_booking", "Restaurant Booking", "Check availability and reserve a private room", HomeCardStatus.Enabled, 1,
                HomeEntryAction.OpenSkill("restaurant_booking")),
            card("meeting_invite", "Meeting Invitation", "Notify attendees and collect responses", HomeCardStatus.Enabled, 2,
                HomeEntryAction.OpenSkill("meeting_notification")),
            card("simultaneous_interpretation", "Live Translation", "Translated Calls", HomeCardStatus.Enabled, 3,
                HomeEntryAction.OpenTranslation),
            card("apology", "Apology", "Deliver an apology on your behalf", HomeCardStatus.ComingSoon, 4,
                HomeEntryAction.OpenSkill("apology_master")),
            card("event_invite", "Event Invitation", "Invite guests to attend", HomeCardStatus.ComingSoon, 5, HomeEntryAction.None),
            card("move_car", "Move Car", "Contact the owner to move the car", HomeCardStatus.ComingSoon, 6, HomeEntryAction.None),
            card("sales_promotion", "Sales Outreach", "Introduce products and services", HomeCardStatus.ComingSoon, 7, HomeEntryAction.None)
        )
    )

    private fun card(
        id: String,
        title: String,
        subtitle: String,
        status: HomeCardStatus,
        sortOrder: Int,
        action: HomeEntryAction
    ) = HomeCard(
        id = id,
        title = title,
        subtitle = subtitle,
        status = status,
        sortOrder = sortOrder,
        imageUrl = null,
        entryAction = action,
        minClientVersion = null
    )
}
