package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.features.assistant_tasks.looksLikeTerminalCallResultStatus
internal fun PersonalInfoEntry.toEffectiveTaskContact(): EffectiveTaskContact {
    return EffectiveTaskContact(
        name = name.trim(),
        gender = gender,
        phone = sfNormalizeMainlandPhone(phone).ifBlank { phone.trim() },
        idCardNumber = idCardNumber.trim()
    )
}

internal fun PersonalInfoGender.sfDisplayLabel(): String = when (this) {
    PersonalInfoGender.Mr -> "先生"
    PersonalInfoGender.Ms -> "女士"
}

internal fun EffectiveTaskContact.sfDisplayName(): String {
    val trimmedName = name.trim()
    if (trimmedName.endsWith("先生") || trimmedName.endsWith("女士")) {
        return trimmedName
    }
    return trimmedName + gender.sfDisplayLabel()
}

internal fun sfParseContactInput(input: String): EffectiveTaskContact? {
    val phoneMatch = Regex("(?:\\+?86[-\\s]*)?1[3-9]\\d(?:[-\\s]*\\d){8}").find(input) ?: return null
    val phone = sfNormalizeMainlandPhone(phoneMatch.value)
    if (phone.isBlank()) return null
    val rawName = input
        .removeRange(phoneMatch.range)
        .replace(Regex("(姓名|联系人|预留|电话|手机号|手机号码|号码|我叫|我是|是|为|：|:|，|,|；|;|。|\\s)+"), " ")
        .trim()
    if (rawName.isBlank()) return null
    val (name, gender) = sfNormalizeContactNameAndGender(rawName)
    val allowedNamePattern = Regex("^[A-Za-z\\u4E00-\\u9FFF\\s·-]{1,12}$")
    if (name.isBlank() || !allowedNamePattern.matches(name)) return null
    return EffectiveTaskContact(
        name = name,
        gender = gender,
        phone = phone
    )
}

internal fun sfNormalizeContactNameAndGender(rawName: String): Pair<String, PersonalInfoGender> {
    val compact = rawName.replace("\\s+".toRegex(), "").trim()
    return when {
        compact.endsWith("女士") -> compact.removeSuffix("女士").trim() to PersonalInfoGender.Ms
        compact.endsWith("先生") -> compact.removeSuffix("先生").trim() to PersonalInfoGender.Mr
        else -> compact to PersonalInfoGender.Mr
    }
}

internal fun sfNormalizeMainlandPhone(value: String): String {
    val normalized = value
        .replace("\\s+".toRegex(), "")
        .replace("-", "")
        .removePrefix("+86")
        .removePrefix("86")
    return if (Regex("^1[3-9]\\d{9}$").matches(normalized)) normalized else ""
}

internal fun sfMaskPhone(phone: String): String {
    val normalized = sfNormalizeMainlandPhone(phone)
    if (normalized.length != 11) return phone
    return normalized.replaceRange(3, 7, "****")
}

internal fun sfBuildDetailSummary(
    supplement: DetailSupplementPageData,
    selectedQuestionIds: List<String>
): String {
    val selectedIdSet = selectedQuestionIds.toSet()
    return supplement.questions
        .filter { selectedIdSet.contains(it.questionId) }
        .map { question -> sfSelectedDetailStatement(question) }
        .filter { it.isNotBlank() }
        .joinToString("；")
}

internal fun sfDetailIdsFromSummary(summary: String): List<String> {
    val normalized = summary.replace("\\s+".toRegex(), "")
    if (normalized.isBlank()) {
        return emptyList()
    }
    return buildList {
        if (normalized.contains("包房") || normalized.contains("包间")) {
            add("needPrivateRoom")
        }
        if (normalized.contains("低消") || normalized.contains("最低消费")) {
            add("askPrivateRoomMinimumSpend")
        }
        if (
            !normalized.contains("不允许无包房") &&
            (normalized.contains("允许无包房") || normalized.contains("可改订大厅") || normalized.contains("可以改大厅"))
        ) {
            add(SfAllowPrivateRoomFallbackToHallQuestionId)
        }
    }.distinct()
}

internal fun sfSelectedDetailStatement(question: DetailSupplementQuestionData): String {
    return when (question.questionId) {
        "needPrivateRoom" -> "需要包房"
        "askPrivateRoomMinimumSpend" -> "需要确认包房低消"
        SfAllowPrivateRoomFallbackToHallQuestionId -> "允许无包房时改订大厅"
        "askCurrentAvailability" -> "需要确认当前是否有位"
        "preferWindowSeat" -> "优先窗边位"
        "smokingRequirement" -> "有抽烟需求"
        "parkingRequirement" -> "需要停车位"
        "quietHighFloorRequirement" -> "需要安静高楼层房间"
        "nonSmokingRoomRequirement" -> "需要无烟房"
        "awayFromStreetRequirement" -> "需要不靠马路临街的房间"
        "windowRoomRequirement" -> "需要窗边房"
        "extraBedRequirement" -> "需要加床"
        "lateCheckoutRequirement" -> "需要延迟退房"
        else -> sfQuestionPromptToStatement(question.prompt)
    }
}

internal fun sfQuestionPromptToStatement(prompt: String): String {
    val text = prompt.trim().trimEnd('。', '？', '?')
    return when {
        text.startsWith("如果有包房，是否还要确认") ->
            "需要确认" + text.removePrefix("如果有包房，是否还要确认")
        text.startsWith("是否还要确认") ->
            "需要确认" + text.removePrefix("是否还要确认")
        text.startsWith("是否需要确认") ->
            "需要确认" + text.removePrefix("是否需要确认")
        text.startsWith("是否需要") ->
            "需要" + text.removePrefix("是否需要")
        text.startsWith("是否优先") ->
            "优先" + text.removePrefix("是否优先")
        text.startsWith("是否有") ->
            "有" + text.removePrefix("是否有")
        else -> text
    }
}
