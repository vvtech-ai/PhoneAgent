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
            HomeSlogan("primary", "给我一个任务", "我来帮你打电话", 1),
            HomeSlogan("secondary", "老大，请吩咐", "我来帮你打电话", 2)
        ),
        cards = listOf(
            card("restaurant_booking", "订餐厅", "帮你询位、预订包房", HomeCardStatus.Enabled, 1,
                HomeEntryAction.OpenSkill("restaurant_booking")),
            card("meeting_invite", "会议邀请", "批量通知参会、确认回执", HomeCardStatus.Enabled, 2,
                HomeEntryAction.OpenSkill("meeting_notification")),
            card("apology", "道歉", "代你表达歉意", HomeCardStatus.ComingSoon, 3,
                HomeEntryAction.OpenSkill("apology_master")),
            card("event_invite", "活动邀约", "邀约嘉宾参加", HomeCardStatus.ComingSoon, 4, HomeEntryAction.None),
            card("move_car", "挪车", "联系车主协调挪车", HomeCardStatus.ComingSoon, 5, HomeEntryAction.None),
            card("sales_promotion", "销售推广", "介绍产品服务", HomeCardStatus.ComingSoon, 6, HomeEntryAction.None),
            card("simultaneous_interpretation", "同声传译", "实时翻译通话。", HomeCardStatus.ComingSoon, 7,
                HomeEntryAction.OpenTranslation)
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
