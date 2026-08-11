package com.vvtech.aiassistant.features.assistant.viewmodel

import com.vvtech.aiassistant.features.assistant.*

import com.vvtech.aiassistant.account.AccountIdentityProvider

/**
 * 顶层常量与简单类型，从 [com.vvtech.aiassistant.features.assistant.AssistantViewModel]
 * 拆出。仅做位置搬迁，不改语义。
 *
 * 拆分依据：这些常量没有任何对 ViewModel 私有状态的依赖，是 top-level 纯量。
 */

internal val DefaultUserId: String
    get() = AccountIdentityProvider.accountId

internal const val DefaultIdleStatus = "点击麦克风，开始描述任务"
internal const val DefaultIdleExample = "例如：帮我给维也纳酒店打电话，确认明晚一人入住。"
internal const val DefaultConfirmLabel = "确认并发起"
internal const val DefaultRetryLabel = "重新说一遍"
internal const val AutoResumeListeningDelayMillis = 360L
internal const val MinAiSpeechResumeDelayMillis = 360L
internal const val MaxAiSpeechResumeDelayMillis = 1200L
internal const val ManualFinishFallbackDelayMillis = 480L
internal const val TakeoverAudioStartDelayMillis = 900L
internal const val TakeoverReconnectDelayMillis = 900L
internal const val AgentTurnLocationAwaitMillis = 10_000L
internal const val LocationRefreshTtlMillis = 2 * 60 * 1000L

internal val LocalFoodSceneHints = listOf(
    "订餐", "餐厅", "菜馆", "川菜", "川菜馆", "海底捞", "粤菜",
    "火锅", "烧烤", "日料", "西餐", "订位", "订座", "周边吃",
    "订座位", "订位置", "订桌", "订台", "餐位", "附近吃", "酒楼",
    "预订餐", "预定餐", "预订座位", "预定座位", "饭店", "饭馆",
    "吃饭", "聚餐", "包间", "包房", "包厢", "低消",
    "restaurant", "book a table", "reserve a table", "table for",
    "dinner reservation", "lunch reservation", "hot pot", "sushi",
    "book a private room", "reserve a private room", "private dining room",
    "book a restaurant", "reserve a restaurant", "restaurant reservation",
    "dining reservation", "meal reservation", "dining room",
    "レストラン", "飲食店", "居酒屋", "焼肉", "寿司", "席を予約"
)
internal val LocalHotelSceneHints = listOf(
    "酒店", "入住", "离店", "维也纳", "大床房", "双床房", "住一晚", "宾馆", "民宿",
    "hotel", "book a hotel", "reserve a hotel", "hotel room", "book a room",
    "reserve a room", "check in", "check-in", "check out", "check-out",
    "ホテル", "宿泊", "チェックイン", "チェックアウト", "部屋を予約"
)
internal val LocalFlightSceneHints = listOf(
    "机票", "订票", "航班", "飞机", "航空", "出发", "到达",
    "单程", "往返", "舱位", "经济舱", "商务舱",
    "flight", "book a flight", "reserve a flight", "plane ticket", "air ticket",
    "one way", "round trip", "economy class", "business class",
    "航空券", "飛行機", "フライト", "片道", "往復"
)
internal val LocalCallSceneHints = listOf(
    "打电话", "拨打", "联系", "帮我打", "帮我联系", "致电", "打给", "传个话",
    "call", "make a call", "phone", "contact", "ring", "tell him", "tell her",
    "ask him", "ask her", "let him know", "let her know",
    "電話", "連絡", "伝えて", "知らせて"
)
internal val BackendStateMachineScenes = setOf(
    "FOOD_ORDERING", "HOTEL_BOOKING", "FLIGHT_BOOKING", "AI_CALL"
)
internal const val BackendPromptPlaybackMarker = "__backend_state_machine_prompt__"

internal val AssistantDialogueMetaPrefixRegex = Regex(
    pattern = "^(我(?:先)?(?:记下|记住)了?你的(?:条件|需求))[，。、“”\\s:：;；,、]*"
)

/**
 * 三种交互通道：语音 / 文字 / 未启用。同时只有一个通道处于活跃状态。
 */
internal enum class InteractionChannel {
    NONE,
    VOICE,
    TEXT
}
