package com.vvtech.aiassistant.features.assistant

import android.icu.text.Transliterator
import com.vvtech.aiassistant.domain.task.isNetworkTaskExecutionStatus
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import java.util.Locale

private val SensitiveNetworkErrorPatterns = listOf(
    Regex("""\b(?:\d{1,3}\.){3}\d{1,3}\b"""),
    Regex("""\bport\s+\d+\b""", RegexOption.IGNORE_CASE),
    Regex("""\b(?:408|425|429|500|502|503|504)\b"""),
    Regex("""http\s*(?:408|425|429|500|502|503|504)""", RegexOption.IGNORE_CASE),
    Regex("""service\s+unavailable|gateway\s+timeout|too\s+many\s+requests""", RegexOption.IGNORE_CASE),
    Regex("""after\s+\d+\s*ms\b""", RegexOption.IGNORE_CASE),
    Regex("""failed\s+to\s+connect""", RegexOption.IGNORE_CASE),
    Regex("""(?:first_audio_timeout|completion_timeout|voice\s+tts\s+failed|tts.*timeout|asr.*timeout|_timeout\b|\btimeout\b)""", RegexOption.IGNORE_CASE),
    Regex("""(?:connect|read|write)\s+timed?\s*out""", RegexOption.IGNORE_CASE),
    Regex("""timed?\s*out""", RegexOption.IGNORE_CASE),
    Regex("""unable\s+to\s+resolve\s+host""", RegexOption.IGNORE_CASE),
    Regex("""unknownhost|sockettimeout|connectexception""", RegexOption.IGNORE_CASE),
    Regex("""connection\s+refused|connection\s+reset|broken\s+pipe""", RegexOption.IGNORE_CASE),
    Regex("""no\s+route\s+to\s+host|network\s+is\s+unreachable""", RegexOption.IGNORE_CASE),
    Regex("""econnrefused|econnreset|enetunreach|ehostunreach|socketexception""", RegexOption.IGNORE_CASE),
    Regex("""sslhandshake|clearttext|cleartext""", RegexOption.IGNORE_CASE),
    Regex("""网络异常|网络连接异常|网络错误|连接异常|连接中断|服务暂时不可用|服务响应超时|请求超时|超时""")
)

/**
 * Failures that indicate the device-to-service transport was actually interrupted.
 *
 * This is intentionally narrower than [SensitiveNetworkErrorPatterns]. HTTP 429/5xx,
 * provider unavailability and model timeouts still need display sanitization, but they
 * are service/model failures rather than proof that the device network is disconnected.
 */
private val TransportNetworkErrorPatterns = listOf(
    Regex("""\bhttp\s*408\b""", RegexOption.IGNORE_CASE),
    Regex("""failed\s+to\s+connect""", RegexOption.IGNORE_CASE),
    Regex("""(?:first_audio_timeout|completion_timeout|voice\s+tts\s+failed|tts.*timeout|asr.*timeout)""", RegexOption.IGNORE_CASE),
    Regex("""(?:connect|read|write)\s+timed?\s*out""", RegexOption.IGNORE_CASE),
    Regex("""connection\s+timed?\s*out""", RegexOption.IGNORE_CASE),
    Regex("""network\s+(?:connection\s+)?(?:error|timeout|failure|unavailable)""", RegexOption.IGNORE_CASE),
    Regex("""unable\s+to\s+resolve\s+host""", RegexOption.IGNORE_CASE),
    Regex("""unknownhost|sockettimeout|connectexception""", RegexOption.IGNORE_CASE),
    Regex("""connection\s+refused|connection\s+reset|connection\s+closed|broken\s+pipe""", RegexOption.IGNORE_CASE),
    Regex("""no\s+route\s+to\s+host|network\s+is\s+unreachable""", RegexOption.IGNORE_CASE),
    Regex("""econnrefused|econnreset|enetunreach|ehostunreach|socketexception""", RegexOption.IGNORE_CASE),
    Regex("""sslhandshake|clearttext|cleartext""", RegexOption.IGNORE_CASE),
    Regex("""网络异常|网络连接异常|网络错误|连接异常|连接中断|无法连接|连接失败|域名解析失败|主机无法解析""")
)

internal fun userFacingNetworkErrorMessage(language: VoiceLanguage): String = when (language) {
    VoiceLanguage.English -> "Network connection error. Please check your network and try again."
    VoiceLanguage.Japanese -> "ネットワーク接続エラーです。ネットワークを確認してから再試行してください。"
    VoiceLanguage.Chinese -> "网络连接异常，请检查网络后重试"
}

internal fun containsSensitiveNetworkError(raw: String?): Boolean {
    val text = raw.orEmpty()
    if (text.isBlank()) return false
    return SensitiveNetworkErrorPatterns.any { it.containsMatchIn(text) }
}

internal fun containsTransportNetworkError(raw: String?): Boolean {
    val text = raw.orEmpty()
    if (text.isBlank()) return false
    return TransportNetworkErrorPatterns.any { it.containsMatchIn(text) }
}

internal fun isNetworkTaskStatus(status: String?): Boolean {
    val normalized = status?.trim().orEmpty()
    if (normalized.isBlank()) return false
    return isNetworkTaskExecutionStatus(normalized) || normalized.contains("网络异常")
}

internal fun networkTaskErrorStatusMessage(language: VoiceLanguage): String = when (language) {
    VoiceLanguage.English -> "Network error. The task is paused. Check your connection and continue."
    VoiceLanguage.Japanese -> "ネットワーク異常です。タスクを一時停止しました。接続を確認してから続けてください。"
    VoiceLanguage.Chinese -> "网络异常，任务已暂停，请检查网络后继续"
}

internal fun sanitizeUserFacingError(
    raw: String?,
    language: VoiceLanguage = VoiceLanguage.Chinese,
    fallback: String = userFacingNetworkErrorMessage(language)
): String {
    val text = raw?.trim().orEmpty()
    if (text.isBlank()) return fallback
    return if (containsSensitiveNetworkError(text)) {
        userFacingNetworkErrorMessage(language)
    } else {
        text
    }
}

internal fun sanitizeUserFacingNetworkText(
    raw: String?,
    language: VoiceLanguage = VoiceLanguage.Chinese
): String {
    val text = stripAgentBackendInstructionForDisplay(raw).orEmpty()
    if (text.isBlank()) return ""
    return when {
        text.contains("想订哪家餐厅") && text.contains("告诉我时间和人数") -> currentAppText(
            text,
            "Which restaurant would you like to book? Tell me the time and party size. You can add any other requirements too."
        )
        containsSensitiveNetworkError(text) -> {
            userFacingNetworkErrorMessage(language)
        }
        language == VoiceLanguage.English -> localizeKnownAssistantNetworkText(text)
        else -> text
    }
}

internal fun sanitizeCallTranscriptDisplayText(
    raw: String?,
    language: VoiceLanguage = VoiceLanguage.Chinese
): String {
    val text = raw?.trim().orEmpty()
    if (text.isBlank()) return ""
    if (language != VoiceLanguage.English) return text
    return localizeCallTranscriptLineForEnglish(text)
}

internal fun stripAgentBackendInstructionForDisplay(raw: String?): String {
    val text = raw.orEmpty().trimStart()
    if (!text.startsWith("Language instruction for this PhoneAgent English demo:")) {
        return text
    }
    val marker = "\nUser request:\n"
    return text.substringAfter(marker, text).trim()
}

internal fun localizedInitialSkillOpening(
    skillId: String?,
    opening: String?,
    language: VoiceLanguage = VoiceLanguage.Chinese
): String? {
    val normalizedSkillId = skillId?.trim().orEmpty()
    if (language == VoiceLanguage.English) {
        englishInitialSkillOpening(normalizedSkillId)?.let { return it }
    }
    val normalizedOpening = opening?.trim()?.takeIf { it.isNotBlank() }
    return normalizedOpening?.let { sanitizeUserFacingNetworkText(it, language) }
}

private fun englishInitialSkillOpening(skillId: String): String? = when (skillId) {
    "restaurant_booking" ->
        "Which restaurant would you like to book? Tell me the time and party size. You can add any other requirements too."

    "meeting_notification" ->
        "Who should I notify about the meeting? Tell me the time, location, and message to pass along."

    "apology_master" ->
        "Who should I call, and what apology would you like me to deliver?"

    "business_event_invitation" ->
        "What event are you inviting them to? Tell me the topic, time, location, and whose name to call under."

    else -> null
}

private fun localizeKnownAssistantNetworkText(raw: String): String {
    var text = raw
    text = localizeKnownStructuredFieldNames(text)
    text = localizeKnownStructuredFieldValues(text)
    text = text.replace(Regex("""Observe:\s*展示\s*(\d+)\s*个选项""")) { match ->
        "Observe: Showing ${match.groupValues[1]} options"
    }
    text = text.replace(Regex("""Observe:\s*(?:未找到|没有找到)\s*(?:候选|candidates?)""", RegexOption.IGNORE_CASE)) {
        "Observe: No candidates found"
    }
    text = text.replace(Regex("""Observe:\s*返回\s*(\d+)\s*(?:家|个)?候选""")) { match ->
        "Observe: Returned ${match.groupValues[1]} candidates"
    }
    text = text.replace(
        Regex("""Observe:\s*返回\s*(\d+)\s*(?:jia\s+hou\s+xuan|ge\s+hou\s+xuan|hou\s+xuan|candidates?)""", RegexOption.IGNORE_CASE)
    ) { match ->
        "Observe: Returned ${match.groupValues[1]} candidates"
    }
    text = text.replace(Regex("""展示\s*(\d+)\s*个选项""")) { match ->
        "Showing ${match.groupValues[1]} options"
    }
    text = text.replace(Regex("""(?:未找到|没有找到)\s*(?:候选|candidates?)""", RegexOption.IGNORE_CASE)) {
        "No candidates found"
    }
    text = text.replace(Regex("""返回\s*(\d+)\s*(?:家|个)?候选""")) { match ->
        "Returned ${match.groupValues[1]} candidates"
    }
    text = text.replace(
        Regex("""返回\s*(\d+)\s*(?:jia\s+hou\s+xuan|ge\s+hou\s+xuan|hou\s+xuan|candidates?)""", RegexOption.IGNORE_CASE)
    ) { match ->
        "Returned ${match.groupValues[1]} candidates"
    }
    mapOf(
        "搜到的结果" to "Search Results",
        "找到的结果" to "Search Results",
        "订餐厅" to "Restaurant Booking",
        "订餐任务" to "Restaurant Booking",
        "会议邀请" to "Meeting Invitation",
        "会议通知" to "Meeting Notification",
        "邀约回执" to "Invitation Receipt",
        "参会人" to "Attendees",
        "确认回执" to "Collect responses",
        "等待用户补充" to "Waiting for user details",
        "项信息" to "detail(s)"
    ).forEach { (chinese, english) ->
        text = text.replace(chinese, english)
    }
    text = text.replace(Regex("""Waiting for user details\s+(\d+)\s+detail\(s\)""")) { match ->
        "Waiting for ${match.groupValues[1]} detail(s) from you"
    }
    text = localizeKnownStructuredFieldNames(text)
    text = localizeKnownStructuredFieldValues(text)
    text = localizeKnownBusinessDataFragments(text)
    return localizeDynamicCjkForEnglish(text)
}

private val CjkTextPattern = Regex("""[\u3400-\u9FFF\uF900-\uFAFF]""")
private val HanToLatinTransliterator: Transliterator? by lazy {
    listOf("Han-Latin/Names; Latin-ASCII", "Han-Latin; Latin-ASCII").firstNotNullOfOrNull { id ->
        runCatching { Transliterator.getInstance(id) }.getOrNull()
    }
}

private fun localizeDynamicCjkForEnglish(raw: String): String {
    if (!CjkTextPattern.containsMatchIn(raw)) {
        val fixedPinyin = localizeKnownBusinessDataFragments(replaceFakePinyinFallbacks(raw))
        return if (fixedPinyin == raw) raw else cleanupEnglishFallbackText(fixedPinyin)
    }
    return raw.lineSequence()
        .map(::localizeDynamicCjkLineForEnglish)
        .joinToString("\n")
}

private fun localizeDynamicCjkLineForEnglish(raw: String): String {
    var text = raw
    text = localizeKnownStructuredFieldNames(text)
    text = localizeKnownBusinessDataFragments(text)
    text = localizeKnownRestaurantNames(text)
    text = localizeCallTranscriptLineForEnglish(text)
    EnglishCjkPhraseReplacements.forEach { (source, replacement) ->
        text = text.replace(source, replacement)
    }
    text = localizeKnownStructuredFieldNames(text)
    text = localizeKnownBusinessDataFragments(text)
    text = transliterateLikelyProperNameFragments(text)
    text = localizeKnownBusinessDataFragments(text)
    return cleanupEnglishFallbackText(text)
}

private fun localizeCallTranscriptLineForEnglish(raw: String): String {
    val direct = localizeKnownMixedCallLine(raw)
    if (!CjkTextPattern.containsMatchIn(direct)) {
        return cleanupEnglishFallbackText(direct)
    }

    var text = direct
    text = localizeKnownRestaurantNames(text)
    text = localizeKnownBusinessDataFragments(text)
    text = localizeCommonCallUtterances(text)
    EnglishCjkPhraseReplacements.forEach { (source, replacement) ->
        text = text.replace(source, replacement)
    }
    text = localizeKnownBusinessDataFragments(text)
    text = transliterateLikelyProperNameFragments(text)
    text = localizeKnownBusinessDataFragments(text)
    return cleanupEnglishFallbackText(text)
}

private fun localizeKnownMixedCallLine(raw: String): String {
    var text = raw.trim()
    val compact = text.replace(Regex("""\s+"""), "")
    when {
        compact.contains("Tonight六点想订一个五peoplePrivateRoom") -> {
            return "I would like to book a private room tonight at 6 p.m. for five people."
        }
        compact.contains("Today晚上六点钟") && compact.contains("五peoplePrivateRoom") -> {
            return "Today at 6 p.m. for five people in a private room. Please wait while I check."
        }
        compact.contains("还YesPrivateRoom吗") -> return "Do you still need a private room?"
        compact.contains("还Yes吗") -> return "Is that correct?"
        compact == "好的,麻烦了" || compact == "好的，麻烦了" -> return "Okay, thank you."
        compact == "麻烦了" -> return "Thank you."
        compact.contains("请稍等") && compact.contains("正在帮您查") -> {
            return "Please wait. I am checking for you."
        }
    }
    text = text.replace(Regex("""(?i)\bTonight\s*六点\s*还\s*Yes\s*Private\s*Room\s*吗\??""")) {
        "Do you still need a private room tonight at 6 p.m.?"
    }
    text = text.replace(Regex("""(?i)\bTonight\s*六点\s*想订一个\s*五\s*people\s*Private\s*Room\.?""")) {
        "I would like to book a private room tonight at 6 p.m. for five people."
    }
    text = text.replace(Regex("""(?i)\bToday\s*晚上六点钟[，,]?\s*五\s*people\s*Private\s*Room\.?""")) {
        "Today at 6 p.m. for five people in a private room."
    }
    text = text.replace(Regex("""(?i)六点"""), "6 p.m.")
    text = text.replace(Regex("""(?i)晚上\s*6\s*p\.m\."""), "6 p.m.")
    text = text.replace(Regex("""(?i)晚上六点钟"""), "6 p.m.")
    text = text.replace(Regex("""(?i)五\s*people"""), "five people")
    text = text.replace(Regex("""(?i)还\s*Yes\s*Private\s*Room\s*吗\??"""), "Do you still need a private room?")
    text = text.replace(Regex("""(?i)还\s*Yes\s*吗\??"""), "Is that correct?")
    text = text.replace("AI 电话媒体已接通，支持人工接管", "AI call connected. Manual takeover is available.")
    text = text.replace("AI电话媒体已接通，支持人工接管", "AI call connected. Manual takeover is available.")
    return text
}

private fun localizeCommonCallUtterances(raw: String): String {
    var text = raw
    text = text.replace(Regex("""(?i)\bTonight\s+6\s*p\.m\.\s+想订一个\s*五?\s*people\s+Private\s+Room\.?""")) {
        "I would like to book a private room tonight at 6 p.m. for five people."
    }
    text = text.replace(Regex("""(?i)\bToday\s+6\s*p\.m\.,?\s*五?\s*people\s+Private\s+Room\.?""")) {
        "Today at 6 p.m. for five people in a private room."
    }
    text = text.replace(Regex("""(?i)想订一个\s*(?:五|5)?\s*people\s+Private\s+Room""")) {
        "would like to book a private room for five people"
    }
    text = text.replace(Regex("""(?i)\b还\s*Yes\s*Private\s+Room\s*吗\??""")) {
        "Do you still need a private room?"
    }
    text = text.replace(Regex("""(?i)\b还\s*Yes\s*吗\??""")) {
        "Is that correct?"
    }
    text = text.replace(Regex("""(?i)请稍等[,，]?\s*我正在帮您查\s*(?:Middle)?\.?""")) {
        "Please wait while I check."
    }
    text = text.replace(Regex("""(?i)我正在帮您查\s*(?:Middle)?""")) {
        "I am checking for you"
    }
    text = text.replace(Regex("""(?i)好的[,，]?\s*麻烦了\.?""")) {
        "Okay, thank you."
    }
    text = text.replace(Regex("""(?i)麻烦了\.?""")) {
        "Thank you."
    }
    text = text.replace("想订一个", "would like to book a ")
    text = text.replace("还", "")
    text = text.replace("吗", "")
    return text
}

private val EnglishCjkPhraseReplacements = listOf(
    "预订脚本已生成" to "Booking script generated",
    "预定脚本已生成" to "Booking script generated",
    "订餐脚本已生成" to "Booking script generated",
    "正在拨打电话" to "Calling",
    "正在拨打" to "Calling",
    "拨打电话" to "Calling",
    "电话尾号" to "phone number ending in ",
    "手机尾号" to "phone number ending in ",
    "号码尾号" to "phone number ending in ",
    "尾号" to "ending in ",
    "已确认拨打" to "Call confirmed",
    "拨打失败" to "Call failed",
    "准备拨打" to "Ready to call",
    "信息确认完毕，准备拨打电话" to "Details confirmed. Ready to place the call",
    "信息确认完毕" to "Details confirmed",
    "准备呼叫" to "Ready to call",
    "呼叫中" to "Calling",
    "通话中" to "Call in progress",
    "已接通" to "Connected",
    "已挂断" to "Call ended",
    "确认通话结果" to "Confirming call result",
    "确认拨打结果" to "Confirming call result",
    "通话任务字段" to "Call task field",
    "电话媒体已接通，支持人工接管" to "call connected. Manual takeover is available",
    "已预订大厅座" to "Main-hall seating booked",
    "已预订" to "Booked",
    "已确认" to "Confirmed",
    "包间已满" to "Private rooms are full",
    "包房已满" to "Private rooms are full",
    "包房：已满" to "Private Room: full",
    "包间：已满" to "Private Room: full",
    "低消信息：无低消" to "Minimum Spend: none",
    "无低消" to "No minimum spend",
    "低消信息" to "Minimum Spend",
    "低消" to "minimum spend",
    "备注" to "Note",
    "门店已登记" to "The store registered",
    "商家" to "Merchant",
    "门店" to "Store",
    "店员" to "Staff",
    "大厅" to "Main hall",
    "包房" to "Private Room",
    "包间" to "Private Room",
    "包厢" to "Private Room",
    "座位" to "Seat",
    "需要包房" to "Private room needed",
    "不需要包房" to "No private room needed",
    "有" to "Yes",
    "无" to "No",
    "男士" to "Mr.",
    "先生" to "Mr.",
    "女士" to "Ms.",
    "要通知谁几点在哪开会？我来帮你打电话通知。" to
        "Who should I notify about the meeting? Tell me the time and location, and I can call them for you.",
    "要通知" to "Who should I notify",
    "几点在哪开会" to "meeting time and location",
    "我来帮你打电话通知" to "I can call them for you",
    "通知谁" to "who to notify",
    "开会" to "meeting",
    "会议邀请" to "Meeting Invitation",
    "会议通知" to "Meeting Notification",
    "邀约回执" to "Invitation Receipt",
    "确认回执" to "Collect responses",
    "参会人" to "Attendees",
    "参会" to "attend",
    "通知" to "notify",
    "回执" to "response",
    "邀请" to "invitation",
    "你好，我是订餐厅助手。想订哪家餐厅、什么时间几位？" to
        "Hi, I can help book a restaurant. Which restaurant, what time, and how many people?",
    "我是订餐厅助手" to "I can help book a restaurant",
    "想订哪家餐厅" to "Which restaurant would you like to book",
    "什么时间几位" to "what time, and how many people",
    "还有其他要求也可以一起说" to "You can add any other requirements too",
    "搜到的结果" to "Search Results",
    "找到的结果" to "Search Results",
    "等待用户补充" to "Waiting for user details",
    "正在帮您查" to "I am checking for you",
    "请稍等" to "Please wait",
    "好的，麻烦了" to "Okay, thank you",
    "好的" to "Okay",
    "麻烦了" to "Thank you",
    "返回候选" to "Returned candidates",
    "家候选" to " candidates",
    "个候选" to " candidates",
    "候选" to "candidates",
    "展示" to "Showing",
    "个选项" to " options",
    "商家表示无需短信确认" to "The merchant said no SMS confirmation is needed",
    "无需短信确认" to "No SMS confirmation needed",
    "任务完成" to "Task Complete",
    "预订成功" to "Reservation confirmed",
    "预订结果" to "Reservation Result",
    "餐厅预订" to "Restaurant Booking",
    "订餐厅" to "Restaurant Booking",
    "订餐任务" to "Restaurant Booking",
    "使用模型" to "Model",
    "平均时延" to "Average Latency",
    "状态" to "Status",
    "任务" to "Task",
    "餐厅" to " Restaurant ",
    "人数" to "Party Size",
    "时间" to "Time",
    "短信" to "SMS",
    "今天" to "Today ",
    "今日" to "Today ",
    "今晚" to "Tonight ",
    "明天" to "Tomorrow ",
    "后天" to "The day after tomorrow ",
    "助手" to " assistant ",
    "饭店" to " Restaurant ",
    "酒楼" to " Restaurant ",
    "酸菜鱼" to " Pickled Fish ",
    "砂锅粥" to " Clay Pot Congee ",
    "火锅" to " Hot Pot ",
    "烧烤" to " Barbecue ",
    "粤菜" to " Cantonese Cuisine ",
    "川菜" to " Sichuan Cuisine ",
    "员村四横路" to " Yuancun 4th Cross Road ",
    "员村三横路" to " Yuancun 3rd Cross Road ",
    "员村" to " Yuancun ",
    "天河" to " Tianhe ",
    "广州" to " Guangzhou ",
    "广东" to " Guangdong ",
    "分店" to " Branch ",
    "号店" to " Branch ",
    "门店" to " Branch ",
    "横路" to " Cross Road ",
    "大道" to " Avenue ",
    "路" to " Road ",
    "街" to " Street ",
    "巷" to " Lane ",
    "东" to " East ",
    "南" to " South ",
    "西" to " West ",
    "北" to " North ",
    "中" to " Middle ",
    "号" to " No. ",
    "位" to " people ",
    "人" to " people "
)

private val EnglishStructuredFieldNames = listOf(
    "restaurantName" to "Restaurant",
    "hotelName" to "Hotel",
    "targetName" to "Target",
    "reservationTime" to "Time",
    "mainDate" to "Time",
    "partySize" to "Party Size",
    "guestCount" to "Party Size",
    "contactPhone" to "Phone",
    "phoneNumber" to "Phone",
    "contactName" to "Contact",
    "privateRoom" to "Private Room",
    "needPrivateRoom" to "Private Room",
    "primaryGoal" to "Primary Goal",
    "openingText" to "Opening Line",
    "summaryLines" to "Summary",
    "negotiationRules" to "Negotiation Rules",
    "successCriteria" to "Success Criteria",
    "TargetName" to "Target",
    "PrimaryGoal" to "Primary Goal",
    "Script" to "Script",
    "Phone" to "Phone"
)

private val KnownRestaurantNameReplacements = listOf(
    "陈辉记私房菜" to "Chen Hui Ji Private Kitchen",
    "李家宴" to "Li Family Banquet",
    "盛禧家宴" to "Sheng Xi Family Banquet",
    "天鲜火锅" to "Fresh Hotpot",
    "一哥酸菜鱼" to "Brother Yi Pickled Fish",
    "潮胜老五砂锅粥" to "Chaoshen Clay Pot Congee",
    "吉利Restaurant3号店" to "Jili Restaurant No. 3 Branch",
    "吉利餐厅3号店" to "Jili Restaurant No. 3 Branch",
    "新荣记" to "Xin Rong Ji",
    "海底捞" to "Haidilao"
)

private val FakePinyinFallbackReplacements = listOf(
    Regex("""\bjia\s+hou\s+xuan\b""", RegexOption.IGNORE_CASE) to "candidates",
    Regex("""\bge\s+hou\s+xuan\b""", RegexOption.IGNORE_CASE) to "candidates",
    Regex("""\bhou\s+xuan\b""", RegexOption.IGNORE_CASE) to "candidates",
    Regex("""\bshi\s+dai\s+guang\s+chang\b""", RegexOption.IGNORE_CASE) to "Times Square",
    Regex("""\btian\s+he\s+bei\s+lu\b""", RegexOption.IGNORE_CASE) to "Tianhe North Road",
    Regex("""\bling\s+tang\s+xin\s+zhuang\b""", RegexOption.IGNORE_CASE) to "Lingtang Xinzhuang",
    Regex("""\bfu\s+jin\s+huo\s+lu\s+shan\s+chuang\s+yi\s+yuan\b""", RegexOption.IGNORE_CASE) to
        "near Huolushan Creative Park",
    Regex("""\bhuo\s+lu\s+shan\s+chuang\s+yi\s+yuan\b""", RegexOption.IGNORE_CASE) to
        "Huolushan Creative Park",
    Regex("""\bzheng\s+zai\s+bo\s+da\s+dian\s+hua\b""", RegexOption.IGNORE_CASE) to "Calling",
    Regex("""\byu\s+ding\s+jiao\s+ben\s+yi\s+sheng\s+cheng\b""", RegexOption.IGNORE_CASE) to
        "Booking script generated",
    Regex("""\bzheng\s+zai\s+que\s+ren\s+tong\s+hua\s+jie\s+guo\b""", RegexOption.IGNORE_CASE) to
        "Confirming call result",
    Regex("""\bwu\s+di\s+xiao\b""", RegexOption.IGNORE_CASE) to "No minimum spend"
)

private fun localizeKnownStructuredFieldNames(raw: String): String {
    var text = raw
    EnglishStructuredFieldNames.forEach { (source, replacement) ->
        text = text.replace(Regex("""\b${Regex.escape(source)}\b"""), replacement)
    }
    return text
}

private fun localizeKnownStructuredFieldValues(raw: String): String {
    var text = raw
    listOf("Private Room").forEach { label ->
        text = text.replace(Regex("""(?m)(\b${Regex.escape(label)}\b\s*[:=]?\s*)true\b""")) {
            "${it.groupValues[1]}Yes"
        }
        text = text.replace(Regex("""(?m)(\b${Regex.escape(label)}\b\s*[:=]?\s*)false\b""")) {
            "${it.groupValues[1]}No"
        }
    }
    text = text.replace(Regex("""(?m)(\bParty Size\b\s*[:=]?\s*)(\d+)\b(?!\s*people)""")) {
        "${it.groupValues[1]}${it.groupValues[2]} people"
    }
    return text
}

private fun localizeKnownRestaurantNames(raw: String): String {
    var text = raw
    KnownRestaurantNameReplacements.forEach { (source, replacement) ->
        text = text.replace(source, replacement)
    }
    return text
}

private fun transliterateLikelyProperNameFragments(raw: String): String {
    if (!CjkTextPattern.containsMatchIn(raw)) return raw
    val transliterator = HanToLatinTransliterator ?: return raw
    return Regex("""(?<![A-Za-z])[\u3400-\u9FFF\uF900-\uFAFF]{2,8}(?=\s*(?:Restaurant|Hot Pot|Pickled Fish|Clay Pot Congee|Branch|\(|$))""")
        .replace(raw) { match ->
            transliterator.transliterate(match.value)
        }
}

private fun cleanupEnglishFallbackText(raw: String): String {
    val punctuationNormalized = replaceFakePinyinFallbacks(raw)
        .replace("（", "(")
        .replace("）", ")")
        .replace("，", ", ")
        .replace("。", ". ")
        .replace("、", ", ")
        .replace("：", ": ")
        .replace("；", "; ")
    return punctuationNormalized
        .replace(Regex("""[ \t\u00A0]+"""), " ")
        .replace(Regex("""\s+([,.;:)])"""), "$1")
        .replace(Regex("""([(])\s+"""), "$1")
        .replace(Regex("""\s*\|\s*"""), " | ")
        .replace(Regex("""\s+-\s+"""), "-")
        .trim()
        .replaceFirstChar { first ->
            if (first.isLowerCase()) first.titlecase(Locale.US) else first.toString()
        }
}

private fun replaceFakePinyinFallbacks(raw: String): String {
    var text = raw
    FakePinyinFallbackReplacements.forEach { (pattern, replacement) ->
        text = text.replace(pattern, replacement)
    }
    return text
}

private fun localizeKnownBusinessDataFragments(raw: String): String {
    var text = raw
    text = text.replace(Regex("""今晚\s*(\d{1,2})\s*点(?:钟)?""")) { match ->
        "tonight at ${formatChineseHourForEnglish(match.groupValues[1], preferPm = true)}"
    }
    text = text.replace(Regex("""晚上\s*(\d{1,2})\s*点(?:钟)?""")) { match ->
        "at ${formatChineseHourForEnglish(match.groupValues[1], preferPm = true)}"
    }
    text = text.replace(Regex("""今天\s*(\d{1,2})\s*点(?:钟)?""")) { match ->
        "today at ${formatChineseHourForEnglish(match.groupValues[1])}"
    }
    text = text.replace(Regex("""明天\s*(\d{1,2})\s*点(?:钟)?""")) { match ->
        "tomorrow at ${formatChineseHourForEnglish(match.groupValues[1])}"
    }
    text = text.replace(Regex("""第\s*(\d+)\s*个""")) { match ->
        "Option ${match.groupValues[1]}"
    }
    text = text.replace(Regex("""尾号\s*[:：]?\s*(\d{3,4})""")) { match ->
        "ending in ${match.groupValues[1]}"
    }
    text = text.replace(Regex("""(?i)\bending\s+in\s+ending\s+in\b"""), "ending in")
    listOf(
        "时代广场" to "Times Square",
        "天河北路" to "Tianhe North Road",
        "凌塘新庄北巷" to "Lingtang Xinzhuang North Lane",
        "凌塘新庄" to "Lingtang Xinzhuang",
        "市欣榆文化发展Yes限公司" to "Xinyu Cultural Development Co., Ltd.",
        "市欣榆文化发展有限公司" to "Xinyu Cultural Development Co., Ltd.",
        "广州市欣榆文化发展有限公司" to "Guangzhou Xinyu Cultural Development Co., Ltd.",
        "欣榆文化发展有限公司" to "Xinyu Cultural Development Co., Ltd.",
        "欣榆文化发展" to "Xinyu Cultural Development",
        "欣榆" to "Xinyu",
        "文化发展有限公司" to "Cultural Development Co., Ltd.",
        "文化发展" to "Cultural Development",
        "有限公司" to "Co., Ltd.",
        "广州市" to "Guangzhou",
        "火炉山创意园" to "Huolushan Creative Park",
        "西门附近" to "near the west entrance",
        "东门附近" to "near the east entrance",
        "南门附近" to "near the south entrance",
        "北门附近" to "near the north entrance",
        "门附近" to "near the entrance",
        "附近" to "near",
        "私房菜" to "Private Kitchen",
        "家宴" to "Family Banquet",
        "周一" to "Monday",
        "周二" to "Tuesday",
        "周三" to "Wednesday",
        "周四" to "Thursday",
        "周五" to "Friday",
        "周六" to "Saturday",
        "周日" to "Sunday",
        "周天" to "Sunday"
    ).forEach { (source, replacement) ->
        text = text.replace(source, replacement)
    }
    text = text.replace(Regex("""(?i)\b(Tianhe North Road|Road)\s*店\b""")) { match ->
        "${match.groupValues[1]} store"
    }
    text = text.replace(Regex("""(?i)\bGuangzhou\s+市\b"""), "Guangzhou")
    text = text.replace(Regex("""(?i)\bF(\d+)F\b""")) { match ->
        "F${match.groupValues[1]}"
    }
    text = text.replace(Regex("""(?i)\bF\s*(\d+)\s*层""")) { match ->
        "F${match.groupValues[1]}"
    }
    text = text.replace(Regex("""(?i)\b(\d+)\s*层""")) { match ->
        "${match.groupValues[1]}F"
    }
    text = text.replace(Regex("""(\d+)\s*区""")) { match ->
        "Zone ${match.groupValues[1]}"
    }
    text = text.replace(Regex("""(?i)\bWest\s+门附近\b"""), "near the west entrance")
    text = text.replace(Regex("""(?i)\bEast\s+门附近\b"""), "near the east entrance")
    text = text.replace(Regex("""(?i)\bNorth\s+门附近\b"""), "near the north entrance")
    text = text.replace(Regex("""(?i)\bSouth\s+门附近\b"""), "near the south entrance")
    text = text.replace(Regex("""(?i)\bYes\s*限公司\b"""), "Co., Ltd.")
    text = text.replace(Regex("""(?i)\bfu\s+jin\b"""), "near")
    text = text.replace(Regex("""(?i)\bmen\s+fu\s+jin\b"""), "near the entrance")
    text = text.replace(Regex("""(?i)\bdian\b"""), "store")
    text = text.replace(Regex("""(?i)\bceng\b"""), "floor")
    text = text.replace(Regex("""(?i)\bhao\b"""), "No.")
    text = text.replace(Regex("""(?i)\bqu\b"""), "Zone")
    return text
}

private fun formatChineseHourForEnglish(rawHour: String, preferPm: Boolean = false): String {
    val hour = rawHour.toIntOrNull() ?: return "$rawHour:00"
    val normalizedHour = if (preferPm && hour in 1..11) hour + 12 else hour
    return when {
        normalizedHour == 0 -> "12 a.m."
        normalizedHour < 12 -> "$normalizedHour a.m."
        normalizedHour == 12 -> "12 p.m."
        normalizedHour <= 23 -> "${normalizedHour - 12} p.m."
        else -> "$hour:00"
    }
}
